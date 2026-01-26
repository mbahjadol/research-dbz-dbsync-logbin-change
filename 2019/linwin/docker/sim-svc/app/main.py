from fastapi import FastAPI
from app.db import insert_random_data, update_random_data
import asyncio
import os
import time

app = FastAPI(title="SQL Server Simulation Service")

# --- Config ---
QPS_INSERT = float(os.getenv("QPS_INSERT", "1"))
QPS_UPDATE = float(os.getenv("QPS_UPDATE", "1"))

# --- Runtime state ---
insert_task = None
update_task = None
insert_count = 0
update_count = 0
insert_running = False
update_running = False

# --- Async loops ---
async def background_insert_loop():
    global insert_count, insert_running
    delay = 1.0 / QPS_INSERT if QPS_INSERT > 0 else 1.0
    insert_running = True
    print(f"[INFO] Background insert loop started (QPS={QPS_INSERT})")
    while insert_running:
        try:
            insert_random_data()
            insert_count += 1
        except Exception as e:
            print("[ERROR] Insert:", e)
        await asyncio.sleep(delay)
    print("[INFO] Background insert loop stopped")

async def background_update_loop():
    global update_count, update_running
    delay = 1.0 / QPS_UPDATE if QPS_UPDATE > 0 else 1.0
    update_running = True
    print(f"[INFO] Background update loop started (QPS={QPS_UPDATE})")
    while update_running:
        try:
            update_random_data()
            update_count += 1
        except Exception as e:
            print("[ERROR] Update:", e)
        await asyncio.sleep(delay)
    print("[INFO] Background update loop stopped")

# --- Routes ---
@app.get("/sim-insert")
def sim_insert():
    return insert_random_data()

@app.get("/sim-update")
def sim_update():
    return update_random_data()

@app.get("/sim-insert-bg")
async def sim_insert_bg():
    global insert_task
    if insert_task is None or insert_task.done():
        insert_task = asyncio.create_task(background_insert_loop())
        return {"status": "ok", "message": "Background insert started"}
    return {"status": "already_running"}

@app.get("/sim-update-bg")
async def sim_update_bg():
    global update_task
    if update_task is None or update_task.done():
        update_task = asyncio.create_task(background_update_loop())
        return {"status": "ok", "message": "Background update started"}
    return {"status": "already_running"}

@app.get("/stop-insert-bg")
async def stop_insert_bg():
    global insert_running
    if insert_running:
        insert_running = False
        return {"status": "ok", "message": "Stopping background insert"}
    return {"status": "not_running"}

@app.get("/stop-update-bg")
async def stop_update_bg():
    global update_running
    if update_running:
        update_running = False
        return {"status": "ok", "message": "Stopping background update"}
    return {"status": "not_running"}

@app.get("/status")
def get_status():
    return {
        "insert_running": insert_running,
        "update_running": update_running,
        "insert_count": insert_count,
        "update_count": update_count,
        "qps_insert": QPS_INSERT,
        "qps_update": QPS_UPDATE,
    }

@app.get("/sim-update-qps/{qps}")
async def set_update_qps(qps: float):
    global QPS_UPDATE, update_task, update_running

    QPS_UPDATE = qps
    os.environ['QPS_UPDATE'] = str(qps)

    if update_running:
        # Gracefully stop the current task
        update_running = False
        if update_task:
            await asyncio.sleep(0.5)  # allow loop to exit

    # Start a new one
    update_task = asyncio.create_task(background_update_loop())
    return {"status": "ok", "new_qps_update": QPS_UPDATE}


@app.get("/sim-insert-qps/{qps}")
async def set_insert_qps(qps: float):
    global QPS_INSERT, insert_task, insert_running

    QPS_INSERT = qps
    os.environ['QPS_INSERT'] = str(qps)

    if insert_running:
        insert_running = False
        if insert_task:
            await asyncio.sleep(0.5)

    insert_task = asyncio.create_task(background_insert_loop())
    return {"status": "ok", "new_qps_insert": QPS_INSERT}
