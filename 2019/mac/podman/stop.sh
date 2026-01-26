#!/bin/bash

source ./env.sh

echo "Stopping the containers."
podman compose -f ${DC_FILE} down

