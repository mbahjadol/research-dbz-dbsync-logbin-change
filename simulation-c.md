
# 🧪 **Experiment C – Log Rebuild Scenario**

### **Objective**

Menguji dampak rebuild log (penghapusan file `.ldf` dan attach ulang dengan `FOR ATTACH_REBUILD_LOG`) terhadap:

* Keterhubungan log sequence number (LSN) di SQL Server.
* Konsistensi Change Data Capture (CDC).
* Perilaku Debezium Source Connector ketika LSN lama tidak lagi valid.
* Sinkronisasi ulang Availability Group setelah log chain terputus.

---

## **Setup**

* Lingkungan multi-node SQL Server dengan AG (PRIMARY dan SECONDARY).
* CDC aktif pada database `[KICSERP]`.
* Debezium source connector aktif, dengan Kafka sink berjalan normal.
* Monitoring aktif (Grafana, Prometheus, atau log connector).
* Backup path dan data path disesuaikan dengan masing-masing node.

---

## **Steps**

### **C.1 Pre-Check & Baseline**

1. Verifikasi koneksi Debezium aktif dan CDC berjalan:

   ```sql
   SELECT sys.fn_cdc_get_max_lsn() AS current_lsn;
   ```
2. Catat nilai `source_lsn` terakhir dari:

   ```
   curl -s http://localhost:8083/connectors/s1_source/status | jq
   ```
3. Catat kondisi metrics Debezium dan AG sebelum tindakan:

   * `lag` di Grafana
   * `redo_queue_size` dan `log_send_queue_size` di AG

   ```sql
   SELECT drs.database_id, drs.synchronization_state_desc, drs.redo_queue_size, drs.log_send_queue_size
   FROM sys.dm_hadr_database_replica_states drs
   WHERE db_name(drs.database_id) = N'KICSERP';
   ```

---

### **C.2 PRIMARY – Detach & Rebuild Log**

> Operasi ini menyebabkan downtime sementara pada `[KICSERP]` dan memutus AG.

1. **Suspend & Detach database**

   ```sql
   USE master;
   BEGIN TRY
       ALTER DATABASE [KICSERP] SET HADR SUSPEND;
   END TRY
   BEGIN CATCH
       PRINT 'INFO: kemungkinan belum join AG.';
   END CATCH
   GO

   ALTER DATABASE [KICSERP] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
   GO
   EXEC sp_detach_db N'KICSERP';
   GO
   ```

2. **Hapus file `.ldf`** (Langkah OS)

   * Masuk ke folder data (misal `/var/opt/mssql/data/` atau `C:\SQL2022Node1\DB_DATA\`).
   * Hapus semua file `.ldf` untuk KICSERP.
   * Jangan hapus `.mdf` / `.ndf`.

3. **Re-attach dan rebuild log**

   ```sql
   CREATE DATABASE [KICSERP]
   ON (FILENAME = N'/var/opt/mssql/data/KICSERP.mdf')
   FOR ATTACH_REBUILD_LOG;
   GO
   ```

4. **Reconfigure recovery model dan backup**

   ```sql
   ALTER DATABASE [KICSERP] SET MULTI_USER;
   ALTER DATABASE [KICSERP] SET RECOVERY FULL;
   GO

   BACKUP DATABASE [KICSERP]
     TO DISK = N'/var/opt/mssql/backups/KICSERP_FULL.bak'
     WITH INIT, COMPRESSION, STATS = 10;
   GO

   BACKUP LOG [KICSERP]
     TO DISK = N'/var/opt/mssql/backups/KICSERP_LOG1.trn'
     WITH INIT, COMPRESSION, STATS = 10;
   GO
   ```

> 🔍 **Checkpoint:** Pastikan `[KICSERP]` kembali ONLINE, punya log baru, dan recovery model FULL.

---

### **C.3 SECONDARY – Reseed from PRIMARY backup**

1. Transfer file `KICSERP_FULL.bak` dan `KICSERP_LOG1.trn` ke Secondary.
2. Jalankan:

   ```sql
   RESTORE DATABASE [KICSERP]
     FROM DISK = N'C:\SQL2022Node2\BACKUP\KICSERP_FULL.bak'
     WITH NORECOVERY, REPLACE, STATS = 10;
   GO

   RESTORE LOG [KICSERP]
     FROM DISK = N'C:\SQL2022Node2\BACKUP\KICSERP_LOG1.trn'
     WITH NORECOVERY, STATS = 10;
   GO
   ```

---

### **C.4 Rejoin to AG**

1. Dari PRIMARY:

   ```sql
   ALTER AVAILABILITY GROUP KI2022AG ADD DATABASE [KICSERP];
   GO
   ALTER DATABASE [KICSERP] SET HADR RESUME;
   GO
   ```
2. Validasi AG sync:

   ```sql
   SELECT db_name(drs.database_id) AS db_name,
          drs.is_primary_replica,
          drs.synchronization_state_desc,
          drs.is_suspended,
          drs.redo_queue_size,
          drs.log_send_queue_size
   FROM sys.dm_hadr_database_replica_states drs
   WHERE db_name(drs.database_id) = N'KICSERP';
   ```

---

### **C.5 Observation Phase**

> Tujuan: Mengamati efek rebuild log terhadap CDC dan Debezium.

1. **Monitor Debezium logs**
   Jalankan:

   ```
   podman logs -f s1_source
   ```

   Perhatikan:

   * Apakah connector crash / restart.
   * Error seperti:

     ```
     Cannot find LSN in current log chain
     ```
   * Apakah otomatis snapshot ulang.

2. **Monitor Grafana metrics:**

   * `log_lag` spike
   * `replication lag`
   * `total_lag_seconds`
   * `record_committed_total`

3. **Query CDC internal**

   ```sql
   SELECT * FROM cdc.lsn_time_mapping ORDER BY tran_begin_time DESC;
   ```

   → lihat apakah LSN lama masih ada atau sudah diganti total.

---

## **Expected Outcomes**

| Skenario                                 | Outcome                                    | Implikasi                    |
| ---------------------------------------- | ------------------------------------------ | ---------------------------- |
| Log lama dihapus & rebuild               | LSN chain baru terbentuk                   | CDC lama invalid             |
| Debezium masih menyimpan offset LSN lama | Connector error: `Cannot find LSN` / stuck | Harus snapshot ulang         |
| Debezium berhenti lalu di-start ulang    | Snapshot ulang otomatis                    | CDC normal kembali           |
| AG rejoin sukses                         | Database sync ulang dari full backup baru  | Sinkronisasi berjalan normal |
| Tidak ada `.ldf` lama tertinggal         | Log size kecil, growth fresh               | Baseline baru terbentuk      |

---

## **Observation Checklist**

| Item                                   | Status | Notes |
| -------------------------------------- | ------ | ----- |
| Database detached tanpa error          | ☐      |       |
| File .LDF berhasil dihapus             | ☐      |       |
| Database berhasil re-attach dan online | ☐      |       |
| Log baru terbentuk (cek size & path)   | ☐      |       |
| Full + log backup sukses               | ☐      |       |
| Secondary berhasil restore             | ☐      |       |
| Database rejoin ke AG tanpa error      | ☐      |       |
| Debezium connector status checked      | ☐      |       |
| LSN continuity diverifikasi            | ☐      |       |

