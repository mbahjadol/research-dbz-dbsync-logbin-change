# Research: Debezium Connectivity — Synchronize Database When Source Log Bin Change

## 🧩 Background

This research experiment will use almost similar resources scripts and code based on my

[Research: debezium db sync network failed](https://github.com/mbahjadol/research-dbz-dbsync-network-fail)
repository.

With some additional scripts to achieve the research simulation objectives.


---

## 🎯 Objectives

* Observes behavior of debezium cdc connector when the source database log bin is changed or rename or empty

* Analyze it and give analysis recommendations

---
## 🧪 Test Environment / Setup

 * All topology simulation does like my previous project

 * Still using insertion and updating data simulation from my previous research project. 

 * Adding some test that modifying the source database log bin file and change it, so the log bin is empty.

 * Monitor and observe behavior of debezium cdc connector

---

## 🧠 Research Questions / Analysis

 - Analyze debezium connect cdc connector behavior

 - Check integrity of synchronized from source db -> debezium group (it is include all necessary node like kafka, et.al) -> target db 

 - Analyzing what needs to do, are need to use SOP to treat the change the source db of log bin?, or is there any tricks or method to modifying and enchances the debezium group?

