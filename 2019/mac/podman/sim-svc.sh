#!/bin/bash

source ./env.sh

if [ "$1" == "insert-bg" ]; then
  podman exec sim-svc sh -c "curl -s http://localhost:8000/sim-insert-bg; echo" | jq
elif [ "$1" == "update-bg" ]; then
  podman exec sim-svc sh -c "curl -s http://localhost:8000/sim-update-bg; echo" | jq
elif [ "$1" == "stop-insert-bg" ]; then
  podman exec sim-svc sh -c "curl -s http://localhost:8000/stop-insert-bg; echo" | jq
elif [ "$1" == "stop-update-bg" ]; then
  podman exec sim-svc sh -c "curl -s http://localhost:8000/stop-update-bg; echo" | jq
elif [ "$1" == "status" ]; then
  podman exec sim-svc sh -c "curl -s http://localhost:8000/status; echo" | jq
elif [ "$1" == "insert-qps" ]; then
  if [ -z "$2" ]; then
    echo "Please provide QPS number for insert-qps"
    exit 1
  fi
  podman exec sim-svc sh -c "curl -s http://localhost:8000/sim-insert-qps/$2; echo" | jq
elif [ "$1" == "update-qps" ]; then
  if [ -z "$2" ]; then
    echo "Please provide QPS number for update-qps"
    exit 1
  fi
  podman exec sim-svc sh -c "curl -s http://localhost:8000/sim-update-qps/$2; echo" | jq
else
  echo "Usage: $0 {insert-bg|update-bg|stop-insert-bg|stop-update-bg|status|insert-qps <number>|update-qps <number>"
  echo "  insert-bg       - ➕ Start background inserts"
  echo "  update-bg       - ✏️ Start background updates"
  echo "  stop-insert-bg  - ⛔ Stop background inserts"
  echo "  stop-update-bg  - 🚫 Stop background updates"
  echo "  status          - 📦 Get status of background operations"
  echo "  insert-qps      - ⚙️ Set insert qps number"
  echo "  update-qps      - ⚙️ Set update qps number"
fi