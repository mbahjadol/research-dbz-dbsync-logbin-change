[<< Back](./README.md)

# Others Had Claims That Debezium Sync In Milliseconds


### 🧠 1️⃣ What “sync latency in ms” claims really mean

When you see people online or in talks claiming **“Debezium syncs changes in milliseconds”**, they almost always refer to the **ideal best-case, single-record, no-load** conditions:

* local network (no cross-region hops)
* change is already in Kafka memory buffer
* sink connector writes to an in-memory DB or cached target
* no batching or disk contention

➡️ In that case, yes, Debezium can *emit* a change within a few ms of the transaction commit being visible in the binlog or CDC table.

But that’s only the **capture side latency** — not end-to-end database-to-database sync.

---

### ⚙️ 2️⃣ What this simulation measuring (and what production systems see)

This measurement is **END-to-END**:

> source DB → Debezium → Kafka → sink → target DB

That includes:

* polling & parsing the CDC stream
* serialization/deserialization
* Kafka commit + replication
* sink connector batching + JDBC writes + target DB disk flush

Each step adds tens or hundreds of ms.

So this 4–5 seconds average sync latency at low QPS — while spikes push higher — is **completely normal** for:

* moderate hardware (Dockerized MSSQL)
* single task connector
* default Debezium batching (and Kafka acks)
* real disk I/O

Real production deployments with similar topology typically report:

| Deployment                            | Typical Median Lag | 99th Percentile |
| ------------------------------------- | ------------------ | --------------- |
| Local single node (test)              | 2–6 s              | 10–20 s         |
| Production cluster (3 brokers, tuned) | 500 ms – 2 s       | 5 s             |
| Cross-region or under backpressure    | 5–20 s             | 1–2 min spikes  |

So this numbers are already **within realistic “production-scale” range** for a simple setup.

---

### 🧩 3️⃣ Why “ms latency” marketing is misleading

Those claims often measure **connector emission latency** (from binlog entry → Kafka message), not:

* commit → sink DB visible row.
  The latter almost always runs in **hundreds of ms to seconds**, even for tuned systems, because:
* Kafka commit interval (e.g. `linger.ms`, `batch.size`)
* sink batching (`max.batch.size`, `insert.mode=upsert`)
* JDBC round-trips and target DB fsync

---

✅ **Summary**

| Metric               | Your Value             | Typical Range                                                   | Comment                               |
| -------------------- | ---------------------- | --------------------------------------------------------------- | ------------------------------------- |
| Average sync time    | ~4.7 s                 | 2–6 s                                                           | Normal                                |
| Low-load lag never 0 | Common                 | Debezium uses micro-batches; idle offset commits delay clearing |                                       |
| “ms latency” claims  | Marketing / ideal-case | —                                                               | Ignore unless they specify end-to-end |

---
---
---
---
---



# THE CALCULATIONS

Let’s do the math step-by-step (digit-by-digit) for both the **low phase** and the **spike (high) phase**, using the same QPS for this simulation (Insert = 2 r/s, Update = 10 r/s).

---

## Inputs

* Insert QPS = **2** records/sec
* Update QPS = **10** records/sec

### Observed (new)

* **Low phase**: insert_lag = **8**, update_lag = **33**
* **Spike (high)**: insert_lag = **109**, update_lag = **496**

---

# A — Low phase calculations

### Insert average sync time

* formula: `time = lag ÷ rate`
* `lag = 8`, `rate = 2`
* compute: `8 ÷ 2 = 4`
* **Insert avg sync time = 4.00 seconds**

### Update average sync time

* `lag = 33`, `rate = 10`
* compute: `33 ÷ 10 = 3.3`

  * (33 ÷ 10 = 3 remainder 3 → 3 + 3/10 = 3.3)
* **Update avg sync time = 3.30 seconds**

### Overall average (weighted by QPS)

* total lag = `8 + 33 = 41` records
* total QPS = `2 + 10 = 12` r/s
* compute: `41 ÷ 12`

  * 12 × 3 = 36, remainder 5 → 3 + 5/12
  * 5/12 = 0.416666...
  * 3 + 0.416666... = **3.4166667 s**
* **Overall avg sync time (low) ≈ 3.42 seconds**

---

# B — Spike (high) phase calculations

### Insert average sync time (spike)

* `lag = 109`, `rate = 2`
* compute: `109 ÷ 2`

  * 2 × 54 = 108, remainder 1 → 54 + 1/2 = 54.5
* **Insert avg sync time (spike) = 54.50 seconds**

### Update average sync time (spike)

* `lag = 496`, `rate = 10`
* compute: `496 ÷ 10`

  * 10 × 49 = 490, remainder 6 → 49 + 6/10 = 49.6
* **Update avg sync time (spike) = 49.60 seconds**

### Overall average (weighted by QPS, spike)

* total lag = `109 + 496 = 605` records
* total QPS = `12` r/s
* compute: `605 ÷ 12`

  * 12 × 50 = 600, remainder 5 → 50 + 5/12
  * 5/12 = 0.416666...
  * 50 + 0.416666... = **50.4166667 s**
* **Overall avg sync time (spike) ≈ 50.42 seconds**

---

## Summary (rounded)

* Low phase:

  * Insert ≈ **4.00 s**
  * Update ≈ **3.30 s**
  * Overall ≈ **3.42 s**
* Spike phase:

  * Insert ≈ **54.50 s**
  * Update ≈ **49.60 s**
  * Overall ≈ **50.42 s**

---

## Quick interpretation & next steps

* **Low-phase ~3.4 s overall** is still good / realistic for an end-to-end pipeline with batching and offset flushes.
* **Spike-phase ~50 s overall** is large and indicates your pipeline experienced a backlog where producers outpaced the sink for a while (could be transient: DB I/O, GC, connector task restart, simulated network loss, or other I/O contention).
* Because the spike affects both insert and update topics, suspect **sink-side bottleneck** (DB writes or connection pool saturation) or a temporary pause (GC, network loss). Less likely to be Kafka broker itself since other topics had zero lag earlier.

### Useful actionable checks to correlate spikes

1. Check DB: slow queries / blocked transactions / log flush (during spike times).
2. Check connector task logs & worker GC around the spike.
3. Check Docker host CPU / I/O at spike times (`iostat`, `dstat`, `top`).
4. Confirm no simulated network loss was active when the spike happened.
5. If you haven’t yet: snapshot `LOG-END-OFFSET` and `CURRENT-OFFSET` at two times to compute produced/sec vs consumed/sec to confirm the pace.

---

[<< Back](./README.md)