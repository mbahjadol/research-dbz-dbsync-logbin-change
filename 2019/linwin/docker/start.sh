#!/bin/bash

source ./env.sh

start_time=$(date +%s)

echo "starting the containers."
docker compose -f ${DC_FILE} up -d --build --force-recreate
# docker compose -f ${DC_FILE} up -d #--build --force-recreate

# Include readines-containers.sh
source ./readiness-containers.sh

echo "---------------------------------------------"
echo "Checking for all containers to be fully running."
echo "---------------------------------------------"

check_sqlserver_container "$SOURCE_NAME" "$SOURCE_USER" "$SOURCE_PASSWORD"
check_sqlserver_container "$TARGET_NAME" "$TARGET_USER" "$TARGET_PASSWORD"
check_zookeeper_container
check_kafka_container
check_debezium_connect_container
check_kafka_ui_container
check_kafka_exporter_container
check_prometheus_container
check_grafana_container

echo "All containers are fully running!"
# press_enter

# remove dangling docker images
echo "---------------------------------------------"
echo "Removing dangling docker images..."
docker image prune -f
echo "---------------------------------------------"

# Initialize source and target databases
echo "---------------------------------------------"
echo "initialize the source and target database."
echo "---------------------------------------------"
./initialize-db-source.sh
./initialize-db-target.sh
echo "---------------------------------------------"

# Configure Debezium connectors
echo "---------------------------------------------"
echo "Configuring Debezium connectors."
echo "---------------------------------------------"
./configure.sh
echo "---------------------------------------------"
# press_enter

echo "You can stop all the containers by running the following command:"
echo "${bold}./stop.sh${reset}"

echo "Start Simulating workload by running the following command in a separate terminal:"
./sim-svc.sh insert-bg
./sim-svc.sh update-bg

echo "---------------------------------------------"
echo "👉 Grafana UI: http://localhost:3000"
echo "(default login: admin / admin)"
echo "---------------------------------------------"

end_time=$(date +%s)
elapsed_time=$(echo "$end_time - $start_time" | bc -l)
echo "---------------------------------------------"
echo "All is done in $elapsed_time seconds."
