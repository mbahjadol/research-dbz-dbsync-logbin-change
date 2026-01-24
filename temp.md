Mantap ⚡ — berarti sekarang kamu ingin **eksperimen C yang terkendali & bersih**:

> tujuanmu bukan langsung “merusak”, tapi memastikan **tidak ada transaksi baru** dan **Debezium sudah menyelesaikan semua pembacaan LSN terakhir** sebelum database kamu *detach*.

Dengan kata lain kamu ingin:

1. Hentikan semua *workload writer* (Python insert/update).
2. Tunggu sampai **Debezium catch up (offset up-to-date)**.
3. Setelah itu baru aman untuk `sp_detach_db`.

Kita bahas dalam urutan langkah yang **tepat dan aman**:

---

## 🧩 Tujuan Eksperimen C Versi “Controlled Shutdown”

| Fase | Tujuan                                               |
| ---- | ---------------------------------------------------- |
| A    | Hentikan transaksi & pastikan tidak ada koneksi baru |
| B    | Tunggu CDC Debezium selesai membaca semua LSN        |
| C    | Nonaktifkan CDC                                      |
| D    | Detach database                                      |

---

## ⚙️ FASE A — Hentikan Semua Insert/Update

Langkah ini memastikan tidak ada *writer* aktif di database.

### 1️⃣ Pastikan workload Python berhenti

Kalau kamu jalanin workload via script Python, pastikan kamu stop dulu proses itu.

> Jika kamu ingin memastikan dari sisi SQL saja, jalankan ini untuk memutus semua koneksi ke `inventory` kecuali session kamu sendiri:

```sql
USE master;
GO
DECLARE @kill NVARCHAR(MAX) = N'';
SELECT @kill += 'KILL ' + CAST(session_id AS NVARCHAR(10)) + ';'
FROM sys.dm_exec_sessions
WHERE database_id = DB_ID('inventory') AND session_id <> @@SPID;

EXEC sp_executesql @kill;
PRINT 'INFO: Semua koneksi ke database inventory sudah dihentikan.';
GO
```

> Ini **lebih baik daripada langsung `SINGLE_USER`**, karena kamu tetap bisa monitor log & CDC sementara.

---

## ⚙️ FASE B — Tunggu Debezium “Catch Up”

Kamu ingin memastikan semua perubahan terakhir sudah terkirim ke Kafka.

### Cara Manual (via Kafka Connect REST API)

Jalankan:

```bash
curl -s http://localhost:8083/connectors/s1_source/status | jq
```

Pastikan `state` = `"RUNNING"` dan **tidak ada error**.

Kemudian untuk tahu Debezium sudah *catch up*:

```bash
curl -s http://localhost:8083/connectors/s1_source/tasks/0/status | jq
```

Jika task masih `RUNNING`, lanjutkan observasi lewat metrics Grafana:

* **metric:** `source_record_lag_max`

  * Jika nilainya = `0`, berarti semua perubahan LSN sudah terbaca dan dikirim ke Kafka.
* **metric:** `source_record_lag_millis`

  * Jika mendekati `0`, Debezium tidak tertinggal.

### Alternatif SQL-side Check

Kamu juga bisa lihat dari sistem CDC apakah masih ada LSN belum diambil:

```sql
USE inventory;
GO
EXEC sys.sp_cdc_help_change_data_capture;
```

Perhatikan kolom `start_lsn` dan `end_lsn` — jika `end_lsn` sudah sama atau mendekati `sys.fn_cdc_get_max_lsn()`, artinya Debezium sudah “mengejar” log terakhir.

---

## ⚙️ FASE C — Disable CDC

Setelah yakin semua offset terakhir sudah masuk Kafka:

```sql
USE inventory;
GO
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += 'EXEC sys.sp_cdc_disable_table @source_schema = N''' + s.name + ''', @source_name = N''' + t.name + ''';' + CHAR(13)
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE is_tracked_by_cdc = 1;
IF LEN(@sql) > 0
BEGIN
    EXEC sp_executesql @sql;
    PRINT 'INFO: CDC table-level dinonaktifkan.';
END
ELSE
BEGIN
    PRINT 'INFO: Tidak ada tabel CDC aktif.';
END
GO

EXEC sys.sp_cdc_disable_db;
PRINT 'INFO: CDC database-level dinonaktifkan.';
GO
```

📌 Catatan:

* Setelah langkah ini, **Debezium akan mulai error** karena kehilangan metadata capture instance.
* Tapi tidak masalah, karena kamu sudah memastikan sebelumnya semua LSN terakhir sudah dikirim ke Kafka.

---

## ⚙️ FASE D — Detach Database

Sekarang database siap dilepas tanpa risiko kehilangan data yang belum tersinkron.

```sql
USE master;
GO
ALTER DATABASE [inventory] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
EXEC sp_detach_db N'inventory';
GO
PRINT 'INFO: Database inventory berhasil di-detach dengan aman.';
```

---

## ✅ Ringkasan Rencana Langkah Eksperimen C (Versi Aman)

| Urutan | Aksi                           | Tujuan                          | Catatan                        |
| ------ | ------------------------------ | ------------------------------- | ------------------------------ |
| 1      | Stop workload Python           | Stop penulisan baru             | Manual stop proses             |
| 2      | KILL all session (selain kamu) | Pastikan tidak ada writer aktif | Gunakan script KILL            |
| 3      | Pantau Debezium lag metrics    | Pastikan offset sudah 0         | `source_record_lag_max = 0`    |
| 4      | Disable CDC (table dan db)     | Bersihkan metadata CDC          | Debezium akan fail setelah ini |
| 5      | Set SINGLE_USER + detach       | Lepas database dengan aman      | Tidak kehilangan LSN terakhir  |

---

## 🧠 Tips Tambahan

Jika kamu ingin *otomatis* menunggu sampai Debezium benar-benar “up-to-date”, kamu bisa buat semacam polling REST API loop:

```bash
while true; do
  LAG=$(curl -s http://localhost:8083/metrics | jq '.[] | select(.name=="source_record_lag_max") | .value')
  echo "Lag: $LAG"
  if [ "$LAG" == "0" ]; then
    echo "Debezium up-to-date!"
    break
  fi
  sleep 5
done
```

Baru setelah loop itu selesai, lanjut disable CDC & detach DB.

---

Apakah kamu ingin saya bantu **susunkan skrip SQL + Bash kombinasi** untuk melakukan proses di atas secara otomatis (termasuk tunggu lag=0, disable CDC, detach DB)? Itu bisa jadi *template script* untuk eksperimen C otomatis kamu nanti.



---

<br/>

---

<br/>

---

<br/>

---

<br/>

---



Pertanyaan ini **sangat bagus dan teknis banget**, dan jawabannya:
🧩 **Secara langsung — SQL Server tidak menyediakan cara native untuk “allow hanya session CDC” sambil menolak user lain”.**
Tapi... bisa dibuat **workaround aman dan efektif** ✅.

Mari kita bedah secara teknikal agar kamu bisa pilih strategi yang paling cocok untuk eksperimen C.

---

## ⚙️ 1️⃣ Memahami dulu: siapa “session CDC”

SQL Server menjalankan **CDC (Change Data Capture)** melalui **SQL Agent jobs** di sisi server.
Jadi ada dua tipe session utama yang menyentuh CDC:

| Jenis Session       | Siapa                            | Keterangan                             |
| ------------------- | -------------------------------- | -------------------------------------- |
| **CDC capture job** | `cdc.<capture_instance>_capture` | Membaca log (transaction log reader).  |
| **CDC cleanup job** | `cdc.<capture_instance>_cleanup` | Menghapus record lama di tabel change. |

Dua job ini **berjalan di dalam SQL Server Agent**, dan biasanya **login-nya adalah SQL Server Agent account**, misalnya:

```
NT SERVICE\SQLSERVERAGENT
```

atau

```
NT AUTHORITY\SYSTEM
```

atau

```
domain\sqlagentuser
```

---

## ⚙️ 2️⃣ Cara mengenali session CDC

Kamu bisa cek siapa yang aktif menjalankan CDC saat ini:

```sql
SELECT
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name
FROM sys.dm_exec_sessions s
WHERE s.program_name LIKE '%CDC%'
   OR s.login_name LIKE '%SQLAGENT%'
   OR s.program_name LIKE '%Agent%';
```

Biasanya hasil akan memperlihatkan login agent seperti di atas.

---

## ⚙️ 3️⃣ Strategi “Restrict All Except CDC”

Ada **dua pendekatan realistis**:

---

### 🧩 **Opsi A — Selective KILL (non-CDC sessions only)**

Kamu bisa **KILL semua session yang bukan CDC job**, lalu biarkan session CDC tetap hidup.

```sql
USE master;
GO
DECLARE @kill NVARCHAR(MAX) = N'';

SELECT @kill += 'KILL ' + CAST(session_id AS NVARCHAR(10)) + ';'
FROM sys.dm_exec_sessions
WHERE database_id = DB_ID('inventory')
  AND session_id <> @@SPID
  AND program_name NOT LIKE '%CDC%'
  AND program_name NOT LIKE '%Agent%';

EXEC sp_executesql @kill;

PRINT 'INFO: Semua session non-CDC di database inventory telah dihentikan.';
GO
```

🧠 Catatan:

* Ini **mematikan semua koneksi biasa (app, workload, SSMS, Debezium, dll)**.
* Tapi **CDC job tetap jalan**, jadi Debezium masih bisa menunggu sampai offset selesai.
* Aman untuk fase “catch-up”.

---

### 🧩 **Opsi B — RESTRICTED_USER + manual re-enable CDC session**

Tidak ada cara langsung untuk whitelist CDC di `RESTRICTED_USER` mode, karena mode ini berbasis **role login**, bukan **program_name**.

Tapi kamu bisa:

1. Catat dulu login account yang digunakan oleh CDC (lihat langkah 2).
2. Tambahkan login itu ke role `db_owner` atau `sysadmin` sementara.
3. Set `RESTRICTED_USER`.
4. Hanya CDC job yang tetap bisa akses (karena dia punya role tinggi).

Contoh:

```sql
-- Misalnya CDC job jalan pakai NT SERVICE\SQLSERVERAGENT
EXEC sp_addsrvrolemember N'NT SERVICE\SQLSERVERAGENT', sysadmin;
ALTER DATABASE [inventory] SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE;
```

🧠 Ini cara **lebih aman secara global**, tapi perlu hati-hati dengan permission level.

---

## ⚙️ 4️⃣ Verifikasi Hasil

Setelah kamu menjalankan salah satu cara di atas, cek siapa yang masih tersisa:

```sql
SELECT
    session_id,
    login_name,
    host_name,
    program_name
FROM sys.dm_exec_sessions
WHERE database_id = DB_ID('inventory');
```

Biasanya hasil yang tersisa:

* `NT SERVICE\SQLSERVERAGENT` (CDC)
* session kamu sendiri (sysadmin)
* tidak ada aplikasi/connector lain (misalnya Debezium sudah stop connect).

---

## ✅ Rekomendasi untuk Eksperimen C

Untuk eksperimen kamu (tujuan: **biarkan CDC menyelesaikan pembacaan terakhir**, lalu detach DB),
cara paling **efektif dan aman** adalah:

```sql
USE master;
GO
DECLARE @kill NVARCHAR(MAX) = N'';

SELECT @kill += 'KILL ' + CAST(session_id AS NVARCHAR(10)) + ';'
FROM sys.dm_exec_sessions
WHERE database_id = DB_ID('inventory')
  AND session_id <> @@SPID
  AND program_name NOT LIKE '%CDC%'
  AND program_name NOT LIKE '%Agent%';

EXEC sp_executesql @kill;

PRINT 'INFO: Semua session non-CDC telah dihentikan.';
GO
```

Kemudian biarkan CDC job dan Debezium bekerja sampai `source_record_lag_max` = 0,
baru lanjut ke langkah **disable CDC dan detach**.

---

Apakah kamu ingin saya bantu **gabungkan skrip Fase A (versi selective kill) + Fase B polling lag metrics + Fase C & D SQL** jadi satu urutan otomatis, biar bisa langsung kamu jalankan sebagai *“Controlled Shutdown Script”* untuk eksperimen C?
