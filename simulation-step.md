
---

# Experiments (SQL Server oriented)

Run each experiment in an isolated test environment (same topology as your repo: SQL Server 2019/2022 containers, Zookeeper/Kafka/Connect/Debezium connector and your sink). Capture connector logs, Kafka offsets, CDC tables, and target DB checksums.

## A — Baseline (control)

* Start stack, run your insert/update sim, verify all events reach Kafka and target DB matches source (counts + checksums). Record `sys.fn_cdc_get_min_lsn(...)` and `sys.fn_cdc_get_max_lsn()` for each capture instance and `SELECT COUNT(*)/CHECKSUM` on your tables. ([Debezium][1])

## B — Force CDC cleanup / remove old CDC rows (simulate missing LSNs)

The CDC cleanup removed rows already processed.
We will experiment with a simulation involving two tables— `insert_lag` and `update_lag` —that aggressively perform inserts and updates using the simulate-service.

```sql
DECLARE @cutoff_lsn binary(10);
SET @cutoff_lsn = sys.fn_cdc_get_max_lsn();  -- or slightly before it
EXEC sys.sp_cdc_cleanup_change_table 
    @capture_instance = 'dbo_insert_lag',
    @low_water_mark = @cutoff_lsn;
```

```sql
DECLARE @cutoff_lsn binary(10);
SET @cutoff_lsn = sys.fn_cdc_get_max_lsn();  -- or slightly before it
EXEC sys.sp_cdc_cleanup_change_table 
    @capture_instance = 'dbo_update_lag',
    @low_water_mark = @cutoff_lsn;
```

**ANSWER:**

    The progress of debezium synchronizing flow is not disturbed by this cleanup, because debezium CDC connector is already consume record into kafka. Conclusion: SAFE.


* Or adjust the `retention` of the CDC cleanup job so it runs earlier. Observe whether the connector notices missing LSNs and whether it errors or falls back to snapshot. (Debezium expects CDC tables to contain changes; if they're gone, it will need a new snapshot.) ([Microsoft Learn][2])

## C — Change recovery model + shrink/truncate log (advance/force reuse of VLFs)

We will experiment simulation with 2 scenarios: <br/>
**Workload** here is meaning that Debezium group, insert & update simulation data workflow is running as we expected 
1. Experiment (C1):  Workload running, in database CDC enabled, then we truncate/shrink ldf log table.
2. Experiment (C2): Workload running (except insert & update simulation data we stop), then we truncate/shrink ldf log table.

#### **Possible outcomes (two experiments)** 
**Assumptions**: Debezium SQL Server connector uses SQL Server CDC; CDC capture job is enabled by default; connector is running on Kafka Connect. “Truncate the LDF” here means forcibly removing log records (example method below: switch to SIMPLE and shrink log), which removes LSN ranges that may not yet be captured by CDC.


#### **Outcome list with probabilities (approximate / qualitative)**

1. **No visible data loss — Debezium continues normally**

   * Likely when: CDC capture had already processed (copied) the affected LSNs to CDC tables before truncation.
   * Probability: **~50%** (depends on CDC job lag, workload).
   * Observables: Debezium log continues, connector state stays RUNNING, no LSN gap errors; CDC tables show expected rows.

2. **Debezium encounters missing LSNs and connector fails or pauses with errors**

   * Likely when: truncation removes LSNs that CDC had not yet captured or CDC metadata references missing LSNs.
   * Probability: **~35%** (common if you truncate while heavy write workload and CDC lag exists).
   * Observables: Connector logs show LSN gap / “missing LSN” / “Cannot continue from LSN …” / exceptions; connector may enter FAILED or STOPPED state or repeatedly restart tasks.

3. **CDC shows inconsistent metadata; Debezium keeps running but produces gaps in Kafka (lost changes)**

   * Likely when: CDC captured some changes but not all; Debezium processes what’s in CDC tables and missing changes simply never appear. Debezium might not fail immediately (depends on how it maps LSNs).
   * Probability: **~10%**
   * Observables: Kafka topics have missing events for the timeframe; application-level divergence vs. source DB; CDC LSN mapping shows missing ranges.

4. **Recovery requires re-snapshot (connector reset) — full rebuild of downstream state**

   * This is the likely *remediation* if missing LSNs are detected and you need to restore consistency.
   * Probability of needing this given #2 or #3: **~80–100%** (if you need correct change history).
   * Observables: After resetting offsets and snapshotting, downstream topics repopulated from snapshot.

5. **Unexpected side-effects (SQL Server warnings, need to take new full backup / break log chain)**

   * When you change recovery model/truncate log you break log chain and must perform full backup to re-enable log backups. This is expected side-effect.
   * Probability: **100%** when using methods that break the log chain.



But, before we do the experiment simulation we need to **collect current database info**

Check current database recovery model
```sql
-- 
-- FULL: Requires log backups; supports point-in-time recovery.
-- SIMPLE: Log space is reclaimed automatically; no log backups.
-- BULK_LOGGED: Minimal logging for bulk operations; requires log backups.
-- 
SELECT 
    name AS DatabaseName,
    recovery_model_desc AS RecoveryModel
FROM sys.databases
WHERE name = DB_NAME();  -- current database
```
example result:
| DatabaseName | RecoveryModel |
|---|---|
| inventory | FULL |

<br/>
<br/>

Check current database log file metadata
```sql
SELECT 
    name AS LogicalName,
    type_desc AS FileType,
    size * 8 / 1024 AS SizeMB,
    physical_name AS FilePath
FROM sys.database_files
WHERE type_desc = 'LOG';
```
example result:
| LogicalName | FileType | SizeMB | FilePath |
|---|---|---|---|
| inventory_log | LOG | 392 | /var/opt/mssql/data/inventory_log.ldf |

<br/>

All those information is needed to continue our experiment further.

<br/>

### C.1. Experiment(C1): Workload running, in database CDC enabled, then we truncate/shrink ldf log table.

### C.2. Experiment(C2): Workload running (except insert & update simulation data we stop), then we truncate/shrink ldf log table.



* Switch recovery model to `SIMPLE`, perform heavy operations and `CHECKPOINT`/`DBCC SHRINKFILE` to force log reuse:

```sql
ALTER DATABASE YourDB SET RECOVERY SIMPLE;
DBCC SHRINKFILE('YourDB_log', 1);
CHECKPOINT;
```

* This triggers reuse/truncation of VLFs; if CDC capture depends on transaction log entries that are no longer present, connector may fail to resume. Capture connector logs and LSN comparisons. (See Debezium blog on SQL Server TX log behavior / VLFs.) ([Debezium][3])

## D — Disable CDC on a table/database while connector is running

* Disable CDC (or disable capture on a table) to simulate accidental removal:

```sql
EXEC sys.sp_cdc_disable_table @source_schema = N'dbo', @source_name = N'YourTable', @capture_instance = N'dbo_YourTable';
-- or for DB:
EXEC sys.sp_cdc_disable_db;
```

* Observe connector errors and what Debezium does (logs, failures, re-snapshot behavior). ([Debezium][1])

## E — Simulate incomplete snapshot / connector restart in middle of snapshot

* Stop connector mid-snapshot and then restart with snapshot-mode disallowed to reproduce "previously stopped while taking a snapshot" errors; test reconfiguring `snapshot.mode` to permit snapshot and resume. (Debezium has snapshot handling for SQL Server.) ([Stack Overflow][4])

## F — Restore CDC metadata / restore DB with KEEP_CDC

* Test restoring a DB from backup with `KEEP_CDC` option (if available in your edition) to see whether CDC state can be recovered without re-snapshot. Example:

```sql
RESTORE DATABASE YourDB FROM DISK = '...\backup.bak' WITH REPLACE, KEEP_CDC;
```

* Useful for SOP: if you have backups with CDC, you might restore with CDC retained. (MS doc for KEEP_CDC exists.) ([Microsoft Learn][2])

---

# What to capture / observability (SQL Server-specific)

* Connector logs (`docker logs connect`) (timestamps).
* Debezium connector status: `curl http://connect:8083/connectors/<name>/status`.
* CDC change table contents: `SELECT * FROM cdc.fn_cdc_get_all_changes_<capture_instance>(@from_lsn, @to_lsn, 'all')`.
* Min/max LSN functions: `sys.fn_cdc_get_min_lsn('capture_instance')`, `sys.fn_cdc_get_max_lsn()`. Save values before/after manipulation. ([Meziantou's blog][5])
* SQL Agent jobs: capture `msdb.dbo.sysjobs` / job history for CDC capture/cleanup jobs.
* Source DB: `SELECT COUNT(*)`, `CHECKSUM TABLE` equivalent (or use deterministic CRC via SQL) on relevant tables.
* Target DB: same counts + checksums / `pt-table-checksum` style hash.
* Kafka topics: earliest/latest offsets and consumer lag.
* If connector errors, copy full stack trace — search for messages about missing CDC data or LSN not found.

---

# Key expected behaviors & how to interpret results

* Debezium SQL Server connector records LSN positions and reads CDC change tables; if CDC rows for a needed LSN are cleaned up/purged before the connector reads them, the connector cannot resume from that LSN and will require recovery (snapshot) or manual intervention. ([Debezium][1])
* Truncating/shrinking the transaction log at the SQL level does not directly "delete CDC rows" (CDC stores changes in change tables) — but log reuse behavior (VLF reuse) can affect capture if capture job lags; see blog on VLF/log truncation behavior for SQL Server. ([Debezium][3])
* Disabling CDC or deleting change tables will break connector streaming and normally requires either restoring CDC/history or taking a fresh snapshot (reconfigure `snapshot.mode` appropriately). ([Debezium][1])

---

# Recovery / SOP recommendations for SQL Server environment

1. **Do not delete/mv LDF/MDF at filesystem level.** Use SQL commands and backups. (Dangerous otherwise.) ([Debezium][3])
2. **Increase CDC retention / adjust cleanup job** so CDC change rows are kept long enough for connector to read them — tune retention in msdb CDC jobs or schedule frequent log backups for FULL recovery model. ([Meziantou's blog][5])
3. **Monitor capture and cleanup jobs** (SQL Agent) — alert if capture job lags or cleanup job runs while connector lag > retention window.
4. **If CDC rows lost** and you can restore binlog/transaction log or backups with CDC: restore database with `KEEP_CDC` (if supported) or restore binlog-backed state; otherwise re-snapshot connector (configure `snapshot.mode` to allow snapshot on restart). ([Microsoft Learn][2])
5. **Prefer small, tested snapshot windows in maintenance** — if re-snapshot required, coordinate sink idempotency/upsert so re-snapshot does not create duplicates.
6. **Document emergency flows**: (a) try to restore CDC data from backup/restore with KEEP_CDC, (b) if not possible, pause connector → allow snapshot → restart → verify integrity.

---

# Concrete example commands & script snippets (to drop into your `experiments/`)

`check-lsn.sql`:

```sql
USE YourDB;
SELECT sys.fn_cdc_get_min_lsn('dbo_YourTable') AS min_lsn,
       sys.fn_cdc_get_max_lsn() AS max_lsn;
```

`force-cdc-cleanup.sql`:

```sql
USE YourDB;
-- Danger: will remove older change rows for capture instance
EXEC sys.sp_cdc_cleanup_change_table @capture_instance = N'dbo_YourTable', @low_water_mark = NULL, @threshold = 5000;
-- or specify a low_water_mark LSN to cleanup up to that LSN
```

`shrink-log.sql`:

```sql
ALTER DATABASE YourDB SET RECOVERY SIMPLE;
CHECKPOINT;
DBCC SHRINKFILE('YourDB_log', 1);
ALTER DATABASE YourDB SET RECOVERY FULL;  -- if you want to return to FULL
```

`disable-cdc.sql`:

```sql
USE YourDB;
EXEC sys.sp_cdc_disable_table @source_schema = N'dbo', @source_name = N'YourTable', @capture_instance = N'dbo_YourTable';
-- or for database:
EXEC sys.sp_cdc_disable_db;
```

Run inside container with `docker exec`/`sqlcmd`:

```bash
podman exec -it mssql-container /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -i /tmp/check-lsn.sql
```

(Adapt container names from your repo stack.)

---

# Citations (key sources used)

* Debezium SQL Server connector docs (snapshot + CDC + LSN behavior). ([Debezium][1])
* Microsoft docs: `sys.sp_cdc_cleanup_change_table` (cleanup procedure). ([Microsoft Learn][2])
* Explanation of SQL Server CDC internals & best practices (change tables, cleanup jobs). ([Meziantou's blog][5])
* Blog about SQL Server transaction log VLF / truncation behavior (impact on log reuse). ([Debezium][3])
* Debezium snapshot / snapshot-mode notes & troubleshooting (restarting in the middle of snapshot). ([Stack Overflow][4])

---

If you want, next I can **(pick one)**:
A) Create the full `experiments/sqlserver-binlog-manipulation/` directory contents (scripts, `run-experiment.sh`, and example connector config) as a patch/PR you can drop into your repo; or
B) Generate just the runnable `run-experiment.sh` + SQL scripts (ready to copy into your repo), or
C) Produce a short SOP document (markdown) for operations team listing exactly what to do if CDC data is lost.

Which of A/B/C do you want me to produce now?

[1]: https://debezium.io/documentation/reference/stable/connectors/sqlserver.html?utm_source=chatgpt.com "Debezium connector for SQL Server"
[2]: https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sys-sp-cdc-cleanup-change-table-transact-sql?view=sql-server-ver17&utm_source=chatgpt.com "sys.sp_cdc_cleanup_change_table (Transact-SQL)"
[3]: https://debezium.io/blog/2025/09/08/sqlserver-tx-log/?utm_source=chatgpt.com "Peeking Inside the SQL Server Transaction Log"
[4]: https://stackoverflow.com/questions/78495761/debeziumexception-the-connector-previously-stopped-while-taking-a-snapshot-but?utm_source=chatgpt.com "DebeziumException \"The connector previously stopped ..."
[5]: https://www.meziantou.net/sql-server-change-data-capture.htm?utm_source=chatgpt.com "SQL Server - Change Data Capture (CDC) - Meziantou's blog"
