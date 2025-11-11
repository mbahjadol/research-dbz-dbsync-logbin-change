# 🧪 Research: DBZ - Sim Log Bin Change (Experiment C)

## 🎯 Objective

The objective of this experiment is to **validate that deleting a database log file (.ldf) and recreating it by reattaching the `.mdf` and/or `.ndf` files can be safely performed without stopping the Debezium synchronization process**, as long as it follows a well-defined Standard Operating Procedure (SOP).
This process requires careful observation of Debezium data lag to ensure synchronization continuity during the maintenance operation.

The broader goal is to **establish a reliable SOP** for performing transaction log maintenance on SQL Server databases involved in Debezium-based CDC replication, while keeping the synchronization running continuously.

---

## ⚙️ Experiment Topology

This simulation is conducted using **the exact same topology** from the previous research:
🔗 [https://github.com/mbahjadol/research-dbz-dbsync-network-fail](https://github.com/mbahjadol/research-dbz-dbsync-network-fail)

That topology already includes:

* **SQL Server Source (`source-db`)**
* **Kafka + Kafka Connect (Debezium Source Connector)**
* **Target Database (sink)**
* **Grafana** → for observing *lag metrics*
* **Apache Kafka UI** → for monitoring synchronization event flow
* **sim-svc (Python Service)** → generates continuous *insert* and *update* operations to the source database

All experiment activities and observations are carried out using the built-in tooling in this topology.

---

## 🧩 Experiment Characteristics

* All experiment actions are executed **entirely through SQL queries on the source database** (`source-db`) for consistency and easier automation.
* **Grafana** and **Kafka UI** are used as the primary observability tools.
* The **Python sim-svc** service continuously performs *insert* and *update* operations to simulate real workloads.
* The main focus of the experiment is the **source database** named `inventory`.

---

## 🔬 Experiment Steps

### 1️⃣ Stop DML Activities from Simulation

Suspend all DML (insert & update) operations coming from `sim-svc` to the `inventory` database **without stopping CDC or Debezium synchronization**.
In this simulation, the blocking is implemented using a **login trigger** that prevents connections from hostname `sim-svc`.
For production scenarios, the blocking mechanism can be adjusted (e.g., based on IP address or application name).

---

### 2️⃣ Observe Lag

Use **Grafana** and **Kafka UI** to monitor synchronization status.
Wait until the `lag` value reaches **0 (zero)**, indicating that all transactions from the source have been completely synchronized to the target.

---

### 3️⃣ Deactivate CDC

Deactivate CDC on the `inventory` database and all associated tables.

---

### 4️⃣ Detach the Database

Perform a **detach** operation on the `inventory` database, allowing direct file-level access to `.mdf`, `.ndf`, and `.ldf` files.

---

### 5️⃣ Delete the LDF File

Manually **delete the `.ldf` transaction log file** from the SQL Server data directory.

---

### 6️⃣ Reattach Database & Rebuild Log

Reattach the `inventory` database using only the `.mdf` and/or `.ndf` files (without the `.ldf`),
and rebuild the transaction log during the attach process using SQL Server’s *rebuild log* option.

---

### 7️⃣ Reactivate CDC

Once the database is online again, **reactivate CDC** both at the database and table level, allowing Debezium to resume reading from the new transaction log.

---

### 8️⃣ Re-enable Simulation Access

Drop the login trigger that blocked the `sim-svc` connection so that the simulation process can resume its insert & update operations.

---

### 9️⃣ Observe Synchronization

Monitor **Grafana** and **Kafka UI** once again:

* Ensure that lag values fluctuate normally (increase and decrease periodically).
* Verify that data events are flowing correctly from the source to the sink.

---

### 🔟 Validate Synchronization

Use SQL queries to compare the data between **source** and **target** databases to confirm that synchronization has fully resumed.

---

## 📊 Observation Results

* Grafana shows a **stable fluctuating lag pattern**, confirming that Debezium synchronization remained active throughout the experiment.
* The `sim-svc` resumed normal operations after the login trigger was removed.
* No anomalies were observed in Kafka UI event streams.
* CDC was successfully reactivated without any errors.
* No data loss occurred during the entire process.

---

## ✅ Conclusion

This experiment confirms that:

> 🔹 The process of deleting a `.ldf` log file and rebuilding it using the *detach–delete–re-attach–rebuild* sequence can be safely executed **without stopping the Debezium synchronization**, as long as it follows the proper procedure and timing.

With this approach, a Debezium-based CDC synchronization system can **continue running continuously** even during major database log maintenance operations.

---

