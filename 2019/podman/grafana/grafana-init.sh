#!/bin/bash
set -e

mkdir -p /etc/grafana/provisioning/dashboards_json
curl -L https://grafana.com/api/dashboards/7589/revisions/5/download \
  -o /etc/grafana/provisioning/dashboards_json/kafka-lag-dashboard.json

exec /run.sh
