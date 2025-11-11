
# 🧪 Research: Debezium Connectivity — Synchronize Database When Source Log Bin Change

### (Experiment C — DBZ Sim Log Bin Change)

---

## 🧩 Background

This research experiment extends and builds upon the previous work:
🔗 [Research: Debezium DB Sync Network Fail](https://github.com/mbahjadol/research-dbz-dbsync-network-fail)

It reuses the same topology, scripts, and simulation components, with additional SQL-based procedures designed to test and validate the behavior of Debezium CDC when the **source database transaction log (LDF)** is **deleted, rebuilt, or replaced**.

The experiment aims to simulate a controlled log file change on the source SQL Server database while the Debezium synchronization remains active — and to observe its behavior under these maintenance conditions.

---

## 🎯 Objectives

1. **Observe** Debezium CDC connector behavior when the source database transaction log (LDF) is deleted, recreated, or replaced.
2. **Validate** whether synchronization from source to target can continue without stopping the Debezium connector.
3. **Analyze** the resulting lag metrics, event flow, and data integrity.
4. **Establish** a safe and repeatable **Standard Operating Procedure (SOP)** for performing SQL Server log maintenance in production environments while CDC synchronization is running.
5. **Provide** actionable recommendations or recovery methods for Debezium systems when a log bin change occurs.

---

## ⚙️ Test Environment / Topology Setup

The topology setup is identical to the previous research project, consisting of:

* **SQL Server Source (`source-db`)**
* **Kafka + Kafka Connect (Debezium Source Connector)**
* **Target Database (sink)**
* **Grafana** — for monitoring CDC lag metrics
* **Apache Kafka UI** — for inspecting Debezium event streams
* **`sim-svc` (Python Service)** — continuously performs *insert* and *update* operations to simulate real workloads

All experiments and observations are executed using the same environment, ensuring consistent and reproducible results.

---

## 🧩 Experiment Characteristics

* All experiment activities are performed **entirely through SQL queries** on the `source-db` (no manual intervention through the UI).
* The **simulation workload** (`sim-svc`) generates continuous DML operations until explicitly paused.
* The **Grafana dashboard** and **Kafka UI** are used as the main monitoring tools.
* The focus of the experiment is the database **`inventory`**, which serves as the CDC-enabled source.

---

## 🔬 Experiment Procedure

### 1️⃣ Stop DML Activity from Simulation

Pause all *insert* and *update* operations from `sim-svc` to the `inventory` database **without disabling Debezium CDC**.
In this simulation, a **login trigger** is used to block connections from hostname `sim-svc`.
In production, this step can be adapted by filtering by IP address or application name.

---

### 2️⃣ Observe Lag

Monitor **Grafana** and **Kafka UI**, and wait until the CDC **lag value becomes 0**, ensuring all current transactions have been fully synchronized to the sink.

---

### 3️⃣ Deactivate CDC

Deactivate CDC at the database level and for all tracked tables in `inventory`.

---

### 4️⃣ Detach the Database

Perform a **database detach** to allow direct access to the physical `.mdf`, `.ndf`, and `.ldf` files.

---

### 5️⃣ Delete the LDF File

Remove the `.ldf` (transaction log) file from the SQL Server data directory.

---

### 6️⃣ Reattach & Rebuild Log

Reattach the `inventory` database using only `.mdf` and/or `.ndf` files (without the `.ldf`)
and rebuild the transaction log using SQL Server’s **REBUILD LOG** option.

---

### 7️⃣ Reactivate CDC

After the database is back online, **reactivate CDC** at both the database and table levels so Debezium can resume reading from the new transaction log.

---

### 8️⃣ Re-enable Simulation Access

Remove the login trigger to allow the `sim-svc` process to reconnect and continue its *insert* and *update* workload.

---

### 9️⃣ Observe Synchronization Behavior

Monitor **Grafana** and **Kafka UI**:

* Confirm that lag values fluctuate as expected (increase/decrease pattern).
* Verify that events are continuously flowing from source to sink.

---

### 🔟 Validate Data Synchronization

Compare the **source** and **target** datasets using SQL queries to ensure synchronization is consistent and data integrity is preserved.

---

## 📊 Observations and Findings

* Grafana shows **stable fluctuating lag**, confirming Debezium continued to process CDC events even after the log rebuild.
* The `sim-svc` resumed operation immediately once the login trigger was removed.
* Kafka UI showed a consistent event stream without interruptions.
* CDC reactivation completed successfully with no errors.
* **No data loss or inconsistency** was detected across the experiment cycle.

---

## ✅ Conclusion

> 🔹 The experiment successfully demonstrates that deleting and recreating the SQL Server transaction log (`.ldf`) using a *detach → delete → re-attach → rebuild* procedure can be performed **without stopping Debezium synchronization**, provided that each step follows the correct SOP and timing.

This proves that a CDC-based Debezium system can **continue running continuously** through transaction log maintenance, ensuring operational uptime and data consistency.

---

## 🧠 Research Analysis

This research analyzes:

* **Debezium CDC connector behavior** under log bin change conditions.
* **End-to-end data integrity** across the replication chain — from source DB → Debezium group (Kafka Connect + Kafka Cluster) → target DB.
* The **best-practice SOP** to safely handle transaction log replacement in SQL Server.
* Possible **enhancements or recovery mechanisms** for Debezium connectors when encountering unexpected log file resets.

---

## 🧭 Next Steps Maybe?

* Formalize the full SOP and convert it into an **automated SQL maintenance script** for production.
* Conduct additional experiments covering:

  * Databases using multiple `.ndf` files
  * Multi-schema CDC environments
  * Debezium connectors using offset recovery and retention tuning
* Explore **automatic CDC reactivation strategies** during log rebuild events.

---

