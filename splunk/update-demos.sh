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

function update_root_readme {
    ROOT_README_PATH=${ROOT_README_PATH:-"$SCRIPT_DIR/../README.md"}

    # Download the latest README file from upstream
    curl -L https://raw.githubusercontent.com/open-telemetry/opentelemetry-demo/main/README.md \
        > "$ROOT_README_PATH"

    # add a section to the root README file with a pointer to Splunk customizations
    SEARCH_VAL="## Quick start"
    REPLACE_VAL='## Splunk customizations \
\
A number of customizations have been made to use the demo application with Splunk Observability Cloud, which can be found in the \[\/splunk\](\.\/splunk) folder.  See \[this document\](\.\/splunk\/README.md) for details. \
\
## Quick start'

    sed -i '' "s/${SEARCH_VAL}/${REPLACE_VAL}/g" "$ROOT_README_PATH"

    echo "Completed updating the root README.md file for the OpenTelemetry demo app!"
}

function update_otel_demo_docker {
    DOCKER_COMPOSE_PATH=${DOCKER_COMPOSE_PATH:-"$SCRIPT_DIR/../docker-compose.yml"}
    SPLUNK_DOCKER_COMPOSE_PATH=${SPLUNK_DOCKER_COMPOSE_PATH:-"$SCRIPT_DIR/../splunk/docker-compose.yml"}

    # delete any older versions of the Splunk Docker Compose file
    [ -e "$SPLUNK_DOCKER_COMPOSE_PATH" ] && rm "$SPLUNK_DOCKER_COMPOSE_PATH"

    # Download the YAML file
    curl -L https://raw.githubusercontent.com/open-telemetry/opentelemetry-demo/main/docker-compose.yml \
        > "$DOCKER_COMPOSE_PATH"

    cp "$DOCKER_COMPOSE_PATH" "$SPLUNK_DOCKER_COMPOSE_PATH"

    # replace the OpenTelemetry collector image with the Splunk distribution
    yq eval -i '.services.otelcol.image = "quay.io/signalfx/splunk-otel-collector:latest"' "$SPLUNK_DOCKER_COMPOSE_PATH"

    # add environment variables required by the Splunk distro of the OpenTelemetry collector
    yq eval -i '.services.otelcol.environment += [ "SPLUNK_ACCESS_TOKEN=${SPLUNK_ACCESS_TOKEN}" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.environment += [ "SPLUNK_REALM=${SPLUNK_REALM}" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.environment += [ "SPLUNK_HEC_TOKEN=${SPLUNK_HEC_TOKEN}" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.environment += [ "SPLUNK_HEC_URL=${SPLUNK_HEC_URL}" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.environment += [ "SPLUNK_MEMORY_TOTAL_MIB=${SPLUNK_MEMORY_TOTAL_MIB}" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"

    # update the command used to launch the collector to point to the Splunk-specific config
    yq eval -i '.services.otelcol.command[0] = "--config=/etc/otelcol-config.yml" ' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.otelcol.command[1])' "$SPLUNK_DOCKER_COMPOSE_PATH"

    yq eval -i '.services.otelcol.volumes = [ "./splunk/otelcol-config.yml:/etc/otelcol-config.yml", "./logs:/logs", "./checkpoint:/checkpoint" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"

    # add ports used by the Splunk distro of the OpenTelemetry collector
    yq eval -i '.services.otelcol.ports += [ "9464" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "8888" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "13133" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "14250" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "14268" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "6060" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "9080" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "9411" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otelcol.ports += [ "9943" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"

    echo "Completed updating docker-compose.yml for the OpenTelemetry demo app!"
}

function update_otel_demo_k8s {
    K8S_PATH=${K8S_PATH:-"$SCRIPT_DIR/../kubernetes/opentelemetry-demo.yaml"}
    SPLUNK_K8S_PATH=${SPLUNK_K8S_PATH:-"$SCRIPT_DIR/../splunk/opentelemetry-demo.yaml"}

    # delete any older versions of the Splunk K8s file
    [ -e "$SPLUNK_K8S_PATH" ] && rm "$SPLUNK_K8S_PATH"

    # Download the YAML file
    curl -L https://raw.githubusercontent.com/open-telemetry/opentelemetry-demo/main/kubernetes/opentelemetry-demo.yaml \
        > "$K8S_PATH"

    cp "$K8S_PATH" "$SPLUNK_K8S_PATH"

    # delete the opentelemetry-demo-otelcol ServiceAccount, ConfigMap, Service, and Deployment objects
    yq eval -i 'select(.kind != "ServiceAccount" or .metadata.name != "opentelemetry-demo-otelcol")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "ConfigMap" or .metadata.name != "opentelemetry-demo-otelcol")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Service" or .metadata.name != "opentelemetry-demo-otelcol")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Deployment" or .metadata.name != "opentelemetry-demo-otelcol")' "$SPLUNK_K8S_PATH"

    # replace the OTEL_COLLECTOR_NAME environment variable
    # with a NODE_IP environment variable for all containers
    #      - name: NODE_IP
    #        valueFrom:
    #          fieldRef:
    #            fieldPath: status.hostIP

    # start by replacing the environment variable name
    yq eval -i ' (.. | select(tag == "!!str")) |= sub("OTEL_COLLECTOR_NAME", "NODE_IP")' "$SPLUNK_K8S_PATH"

    # then use sed to replace the value
    # (yq was not used due to an issue that added extraneous elements to the file)
    SEARCH_VAL="value: 'opentelemetry-demo-otelcol'"
    REPLACE_VAL='valueFrom: \
                fieldRef: \
                  fieldPath: status.hostIP'

    sed -i '' "s/${SEARCH_VAL}/${REPLACE_VAL}/g" "$SPLUNK_K8S_PATH"

    # append the deployment.environment resource attribute
    # - name: OTEL_RESOURCE_ATTRIBUTES
    #   value: service.name=$(OTEL_SERVICE_NAME),service.namespace=opentelemetry-demo,deployment.environment=development
    yq eval -i ' (.. | select(tag == "!!str")) |= sub("service.namespace=opentelemetry-demo", "service.namespace=opentelemetry-demo,deployment.environment=development")'  "$SPLUNK_K8S_PATH"

    echo "Completed updating the kubernetes/opentelemetry-demo.yaml for the OpenTelemetry demo app!"
}

# ---- OpenTelemetry Demo Update ----
update_root_readme
update_otel_demo_docker
update_otel_demo_k8s
