#!/usr/bin/env bash
set -euo pipefail
# Purpose: Update demo applications with the latest upstream changes.
# Notes:
#   This script performs updates for the OpenTelemetry Demo.
# Requirements:
#   - yq: A portable command-line YAML processor.
#   Both can be installed using brew:
#       brew install yq
#
# Example Usage:
#   ./update_demos.sh

# Set default paths if environment variables are not set
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

function update_otel_demo_docker {
    DOCKER_COMPOSE_PATH=${DOCKER_COMPOSE_PATH:-"$SCRIPT_DIR/../docker-compose.yml"}

    # Download the YAML file
    curl -L https://raw.githubusercontent.com/open-telemetry/opentelemetry-demo/main/docker-compose.yml \
        > "$DOCKER_COMPOSE_PATH"

    # replace the OpenTelemetry collector image with the Splunk distribution
    yq eval -i '.services.otelcol.image = "quay.io/signalfx/splunk-otel-collector:latest"' "$DOCKER_COMPOSE_PATH"

    # add environment variables required by the Splunk distro of the OpenTelemetry collector
    yq eval -i '.services.otelcol.environment += [ "SPLUNK_ACCESS_TOKEN=${SPLUNK_ACCESS_TOKEN}" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.environment += [ "SPLUNK_REALM=${SPLUNK_REALM}" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.environment += [ "SPLUNK_HEC_TOKEN=${SPLUNK_HEC_TOKEN}" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.environment += [ "SPLUNK_HEC_URL=${SPLUNK_HEC_URL}" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.environment += [ "SPLUNK_MEMORY_TOTAL_MIB=${SPLUNK_MEMORY_TOTAL_MIB}" ]' "$DOCKER_COMPOSE_PATH"

    # update the command used to launch the collector to point to the Splunk-specific config
    yq eval -i '.services.otelcol.command[0] = "--config=/etc/splunk-otelcol-config.yml" ' "$DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.otelcol.command[1])' "$DOCKER_COMPOSE_PATH"

    yq eval -i '.services.otelcol.volumes = [ "./src/otelcollector/splunk-otelcol-config.yml:/etc/splunk-otelcol-config.yml", "./logs:/logs", "./checkpoint:/checkpoint" ]' "$DOCKER_COMPOSE_PATH"

    # add ports used by the Splunk distro of the OpenTelemetry collector
    yq eval -i '.services.otelcol.ports += [ "9464" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "8888" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "13133" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "14250" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "14268" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "6060" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "9080" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "9411" ]' "$DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "9943" ]' "$DOCKER_COMPOSE_PATH"

    echo "OpenTelemetry Demo update completed!"
}

# ---- OpenTelemetry Demo Update ----
update_otel_demo_docker
