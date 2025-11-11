# 🧪 Research: DBZ - Sim Log Bin Change (Experiment C)

## 🎯 Tujuan Eksperimen

Tujuan dari eksperimen ini adalah untuk **memvalidasi bahwa proses penghapusan file log (.ldf) database, dan kemudian melakukan re-create kembali log file melalui re-attach file `.mdf` dan/atau `.ndf`, dapat dilakukan tanpa perlu menghentikan proses sinkronisasi Debezium**.
Dengan kata lain, kita ingin membuktikan bahwa sinkronisasi CDC (Change Data Capture) antara database sumber dan target dapat tetap berfungsi **asalkan prosedur eksekusi dilakukan dengan SOP yang tepat** serta dilakukan observasi ketat terhadap lag data selama proses berlangsung.

Eksperimen ini juga bertujuan untuk **menyusun SOP standar** yang aman untuk melakukan maintenance pada file log database tanpa menyebabkan inkonsistensi data pada sistem sinkronisasi berbasis Debezium.

---

## ⚙️ Topologi Eksperimen

Eksperimen ini dijalankan menggunakan **topologi yang sama persis** dengan riset sebelumnya:
🔗 [https://github.com/mbahjadol/research-dbz-dbsync-network-fail](https://github.com/mbahjadol/research-dbz-dbsync-network-fail)

Topologi tersebut sudah mencakup komponen utama berikut:

* **SQL Server Source (`source-db`)**
* **Kafka + Kafka Connect (Debezium Source Connector)**
* **Target Database (sink)**
* **Grafana** → untuk observasi *lag metrics*
* **Apache Kafka UI** → untuk observasi event log sinkronisasi
* **sim-svc (Python Service)** → service yang melakukan simulasi *insert* & *update* ke `source-db`

Seluruh aktivitas dan observasi dilakukan menggunakan *tooling* bawaan topologi ini.

---

## 🧩 Karakteristik Eksperimen

* Semua aktivitas eksperimen dieksekusi **melalui SQL query langsung ke database sumber** (`source-db`), agar lebih mudah dikontrol dan dieksekusi secara konsisten.
* Observasi utama dilakukan terhadap **lag metrics di Grafana** dan **message flow di Kafka UI**.
* Simulasi *workload* (insert & update) dilakukan oleh Python service (`sim-svc`) untuk memastikan Debezium CDC bekerja seperti kondisi real.
* Fokus eksperimen hanya pada **database sumber** yaitu `inventory`.

---

## 🔬 Langkah Eksperimen

### 1️⃣ Hentikan Aktivitas DML dari Simulasi

Hentikan seluruh aktivitas DML (insert & update) dari `sim-svc` terhadap database `inventory`, **tanpa menghentikan CDC atau proses sinkronisasi Debezium**.
Pada simulasi ini dilakukan dengan:

* Membuat **login trigger** untuk memblokir koneksi dari hostname `sim-svc`.
* Dalam implementasi production, pendekatan ini dapat diganti dengan pemblokiran berdasarkan IP address atau aplikasi tertentu.

---

### 2️⃣ Observasi Lag

Gunakan **Grafana** dan **Kafka UI** untuk memantau kondisi sistem.
Tunggu hingga nilai `lag` benar-benar **0 (nol)** — menandakan seluruh perubahan di source sudah tersinkronisasi sepenuhnya ke target.

---

### 3️⃣ Nonaktifkan CDC

Lakukan **deactivation CDC** pada database `inventory` serta seluruh tabel yang termasuk dalam konfigurasi CDC.

---

### 4️⃣ Detach Database

Lakukan **detach** terhadap database `inventory` agar file fisik `.mdf`, `.ndf`, dan `.ldf` dapat dikelola secara manual.

---

### 5️⃣ Hapus File LDF

Hapus file `.ldf` (transaction log) dari lokasi fisik penyimpanan database di SQL Server.

---

### 6️⃣ Re-Attach Database & Rebuild Log

Re-attach kembali database `inventory` menggunakan hanya file `.mdf` dan/atau `.ndf` (tanpa `.ldf`), dengan menambahkan opsi **rebuild log** agar SQL Server membuat ulang file log baru.

---

### 7️⃣ Aktifkan Kembali CDC

Setelah database aktif kembali, lakukan **aktivasi ulang CDC** pada level database dan seluruh tabel terkait agar Debezium dapat membaca kembali log dari posisi awal yang baru terbentuk.

---

### 8️⃣ Aktifkan Kembali Akses Simulasi

Drop trigger login yang sebelumnya dibuat untuk memblokir `sim-svc`, agar proses simulasi insert & update dapat berjalan kembali secara normal.

---

### 9️⃣ Observasi Sinkronisasi

Pantau kembali kondisi di **Grafana** dan **Kafka UI**:

* Pastikan lag mulai naik-turun secara dinamis.
* Pastikan event log di Kafka kembali mengalir dari source ke sink.

---

### 🔟 Validasi Sinkronisasi

Gunakan query SQL untuk membandingkan data antara database **source** dan **target** guna memastikan bahwa sinkronisasi telah kembali berjalan normal.

---

## 📊 Hasil Observasi

* Lag pada Grafana menunjukkan pola **naik-turun stabil**, yang menandakan proses sinkronisasi data tetap berlangsung selama dan setelah proses rebuild log dilakukan.
* `sim-svc` kembali berfungsi normal setelah trigger login dihapus.
* Tidak ditemukan anomali pada aliran event di Kafka UI.
* CDC berhasil diaktifkan kembali tanpa error.
* Tidak terjadi kehilangan data selama eksperimen dilakukan.

---

## ✅ Kesimpulan

Eksperimen berhasil membuktikan bahwa:

> 🔹 Proses penghapusan file `.ldf` dan rekonstruksi ulang log dengan metode *detach–delete–re-attach–rebuild* dapat dilakukan tanpa menghentikan proses sinkronisasi Debezium, **asalkan dilakukan dengan urutan dan prosedur yang tepat.**

Dengan adanya prosedur ini, sistem sinkronisasi berbasis CDC dapat tetap dipertahankan *running continuously* meskipun dilakukan maintenance besar pada log database.

---
