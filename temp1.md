🎯 Pertanyaan yang sangat tajam — dan ini justru masuk ke lapisan **security-level control di SQL Server** yang jarang disentuh eksperimen biasa.

Jawaban ringkas:

> ❌ SQL Server **tidak memiliki native “whitelist/blacklist IP address”** di level engine-nya,
> ✅ tapi bisa dicapai **secara efektif** lewat 3 pendekatan tergantung arsitek sistemmu.

Mari kita bedah satu per satu — biar kamu tahu opsi mana yang paling cocok untuk skenario Debezium–Python kamu 👇

---

## 🧩 1️⃣ Level SQL Server (native) — *Tidak ada IP filter built-in*

SQL Server **tidak punya** perintah seperti:

```sql
DENY CONNECT FROM '192.168.1.10'
```

Jadi dari sisi engine SQL (`T-SQL`), kamu **tidak bisa memfilter IP address langsung**.

Tetapi ada **trik tidak langsung**:

* Kamu bisa membaca IP address aktif dari `sys.dm_exec_connections`.
* Dan kemudian men-*kill* atau *deny login* secara dinamis berdasarkan IP.

Misalnya:

```sql
-- KILL semua koneksi dari IP tertentu
DECLARE @kill NVARCHAR(MAX) = N'';
SELECT @kill += 'KILL ' + CAST(session_id AS NVARCHAR(10)) + ';'
FROM sys.dm_exec_connections
WHERE client_net_address IN ('172.25.0.10', '172.25.0.11');

EXEC sp_executesql @kill;
PRINT 'INFO: Semua koneksi dari IP ter-blacklist sudah dihentikan.';
```

🧠 Tapi ini **reaktif**, bukan **preventif** —
artinya koneksi bisa masuk sebentar, baru kemudian diputus.

---

## 🧩 2️⃣ Level Firewall (Windows Firewall / Linux iptables) — *Paling efektif*

SQL Server koneksi selalu lewat TCP port (default `1433`).

Jadi kamu bisa **filter IP di firewall host SQL Server**,
dengan whitelist yang spesifik: hanya Debezium + CDC + admin boleh masuk.

### 🪟 Windows example:

```powershell
# Allow only Debezium host & localhost
New-NetFirewallRule -DisplayName "Allow SQL from Debezium" -Direction Inbound -Protocol TCP -LocalPort 1433 -RemoteAddress 172.25.0.5,127.0.0.1 -Action Allow

# Block everyone else
New-NetFirewallRule -DisplayName "Block Other SQL Connections" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Block
```

### 🐧 Linux (iptables example):

```bash
# Allow Debezium and localhost
iptables -A INPUT -p tcp -s 172.25.0.5 --dport 1433 -j ACCEPT
iptables -A INPUT -p tcp -s 127.0.0.1 --dport 1433 -j ACCEPT

# Block everyone else
iptables -A INPUT -p tcp --dport 1433 -j DROP
```

✅ Kelebihan:

* Python client di IP lain langsung ditolak sebelum handshake.
* Debezium (misal dari IP 172.25.0.5) tetap bisa connect.
* Tidak mengganggu CDC internal (karena itu lokal process).

---

## 🧩 3️⃣ Level Login Trigger — *Dynamic in-engine filtering (advanced)*

Kalau kamu ingin **filter IP langsung di dalam SQL Server**,
bisa gunakan **Login Trigger**, yaitu trigger yang dieksekusi setiap kali ada login.

### Contoh:

```sql
CREATE TRIGGER limit_login_ip
ON ALL SERVER
FOR LOGON
AS
BEGIN
    DECLARE @ip NVARCHAR(48);
    SELECT @ip = client_net_address FROM sys.dm_exec_connections WHERE session_id = @@SPID;

    IF @ip NOT IN ('172.25.0.5', '127.0.0.1')
    BEGIN
        PRINT 'Denied login from unauthorized IP: ' + @ip;
        ROLLBACK;
    END
END;
GO
```

📌 Catatan penting:

* Login trigger bisa membatalkan koneksi (`ROLLBACK`).
* Jadi Python dari IP tidak terdaftar akan langsung gagal login.
* Debezium tetap bisa masuk karena IP-nya di whitelist.
* Tapi **hati-hati**: kalau salah konfigurasi (misalnya kamu lupa whitelisting diri sendiri),
  kamu bisa terkunci dari server 😅

---

## ✅ Rekomendasi untuk eksperimenmu

Konteks: kamu sedang jalankan semuanya dalam lingkungan **terkendali (lab/compose)**, misalnya Docker.

Jadi:

* Python dan Debezium kemungkinan jalan dalam **container berbeda**, dengan IP tetap (`172.25.x.x`).
* SQL Server juga dalam container (atau VM) yang bisa diakses antar network bridge.

🧭 **Saran paling aman:**

1. **Gunakan kombinasi login + IP filtering:**

   * Buat login khusus untuk Debezium.
   * Disable login Python sementara.
   * Tambahkan **Login Trigger whitelist** untuk IP Debezium saja.
2. (Kalau environment Docker)
   tambahkan rule iptables di container SQL untuk hanya menerima dari Debezium network alias.

---

## 💡 Bonus: untuk validasi cepat, kamu bisa lihat siapa yang connect dari mana

```sql
SELECT
    s.session_id,
    c.client_net_address AS client_ip,
    s.login_name,
    s.program_name
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON s.session_id = c.session_id
WHERE s.database_id = DB_ID('inventory');
```

Output ini berguna banget untuk debugging apakah Python atau Debezium masih bisa connect.

---

### 🔒 Singkatnya

| Tujuan                                     | Cara                                          |
| ------------------------------------------ | --------------------------------------------- |
| Cegah koneksi Python tapi biarkan Debezium | `Login Trigger` atau `Firewall`               |
| Tidak ganggu CDC internal job              | Aman di semua metode                          |
| Paling aman untuk lab experiment           | Login Trigger (whitelist IP Debezium + admin) |
| Paling sederhana                           | Firewall host/container                       |

---

Kalau kamu mau, saya bisa bantu buatkan **versi login trigger siap-pakai**
yang otomatis whitelist:

* IP Debezium (misal `172.25.0.5`)
* Localhost (`127.0.0.1`)
* Kamu (sysadmin login)

dan menolak semua IP lain (misalnya Python di `172.25.0.10`).
Apakah mau saya tulis yang versi itu?
