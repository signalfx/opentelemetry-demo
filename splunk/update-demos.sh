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

    echo "Completed updating docker-compose.yml for the OpenTelemetry demo app!"
}

function update_otel_demo_k8s {
    K8S_PATH=${K8S_PATH:-"$SCRIPT_DIR/../kubernetes/opentelemetry-demo.yaml"}

    # Download the YAML file
    curl -L https://raw.githubusercontent.com/open-telemetry/opentelemetry-demo/main/kubernetes/opentelemetry-demo.yaml \
        > "$K8S_PATH"

    # delete the opentelemetry-demo-otelcol ServiceAccount, ConfigMap, Service, and Deployment objects
    yq eval -i 'select(.kind != "ServiceAccount" or .metadata.name != "opentelemetry-demo-otelcol")' "$K8S_PATH"
    yq eval -i 'select(.kind != "ConfigMap" or .metadata.name != "opentelemetry-demo-otelcol")' "$K8S_PATH"
    yq eval -i 'select(.kind != "Service" or .metadata.name != "opentelemetry-demo-otelcol")' "$K8S_PATH"
    yq eval -i 'select(.kind != "Deployment" or .metadata.name != "opentelemetry-demo-otelcol")' "$K8S_PATH"

    # delete the OTEL_COLLECTOR_NAME environment variable from all containers
    yq eval -i 'del(.spec.template.spec.containers[].env[] | select(.name == "OTEL_COLLECTOR_NAME"))' "$K8S_PATH"

    # add a NODE_IP environment variable for all containers
    #      - name: NODE_IP
    #        valueFrom:
    #          fieldRef:
    #            fieldPath: status.hostIP

    yq eval -i '(.spec.template.spec.containers[].env) += { "name": "NODE_IP" }' "$K8S_PATH"
    yq eval -i '(.spec.template.spec.containers[].env[] | select(.name == "NODE_IP") | .valueFrom.fieldRef.fieldPath) = "status.hostIP"' "$K8S_PATH"

    # update the OTEL_EXPORTER_OTLP_ENDPOINT environment variable to use the NODE_IP
    yq eval -i '(.spec.template.spec.containers[].env[] | select(.name == "OTEL_EXPORTER_OTLP_ENDPOINT") | .value) ="http://$(NODE_IP):4317"' "$K8S_PATH"

    # update the OTEL_EXPORTER_OTLP_TRACES_ENDPOINT environment variable to use the NODE_IP
    yq eval -i '(.spec.template.spec.containers[].env[] | select(.name == "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT") | .value) ="http://$(NODE_IP):4318/v1/traces"' "$K8S_PATH"

    # append the deployment.environment resource attribute
    # - name: OTEL_RESOURCE_ATTRIBUTES
    #   value: service.name=$(OTEL_SERVICE_NAME),service.namespace=opentelemetry-demo,deployment.environment=development
    yq eval -i '(.spec.template.spec.containers[].env[] | select(.name == "OTEL_RESOURCE_ATTRIBUTES") | .value) += ",deployment.environment=development"' "$K8S_PATH"

    echo "Completed updating the kubernetes/opentelemetry-demo.yaml for the OpenTelemetry demo app!"
}

# ---- OpenTelemetry Demo Update ----
update_otel_demo_docker
update_otel_demo_k8s
