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
    REPLACE_VAL='## Splunk customizations\
\
A number of customizations have been made to use the demo application with\
Splunk Observability Cloud, which can be found in the \[\/splunk\](\.\/splunk)\
folder.  See \[this document\](\.\/splunk\/README.md) for details.\
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

    # delete containers that are not required
    yq eval -i 'del(.services.grafana)' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.jaeger)' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.prometheus)' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.opensearch)' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.frontendTests)' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.traceBasedTests)' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.tracetest-server)' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.tracetest-postgres)' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.frontend-proxy.depends_on.jaeger)' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.frontend-proxy.depends_on.grafana)' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.otel-collector.depends_on)' "$SPLUNK_DOCKER_COMPOSE_PATH"

    # replace the OpenTelemetry collector image with the Splunk distribution
    yq eval -i '.services.otel-collector.image = "quay.io/signalfx/splunk-otel-collector:latest"' "$SPLUNK_DOCKER_COMPOSE_PATH"

    # add environment variables required by the Splunk distro of the OpenTelemetry collector
    yq eval -i '.services.otel-collector.environment += [ "SPLUNK_ACCESS_TOKEN=${SPLUNK_ACCESS_TOKEN}" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otel-collector.environment += [ "SPLUNK_REALM=${SPLUNK_REALM}" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otel-collector.environment += [ "SPLUNK_HEC_TOKEN=${SPLUNK_HEC_TOKEN}" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otel-collector.environment += [ "SPLUNK_HEC_URL=${SPLUNK_HEC_URL}" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otel-collector.environment += [ "SPLUNK_MEMORY_TOTAL_MIB=${SPLUNK_MEMORY_TOTAL_MIB}" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"

    # update the command used to launch the collector to point to the Splunk-specific config
    yq eval -i '.services.otel-collector.command[0] = "--config=/etc/otelcol-config.yml" ' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i 'del(.services.otel-collector.command[1])' "$SPLUNK_DOCKER_COMPOSE_PATH"

    yq eval -i '.services.otel-collector.volumes = [ "./splunk/otelcol-config.yml:/etc/otelcol-config.yml", "./logs:/logs", "./checkpoint:/checkpoint" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"

    # add ports used by the Splunk distro of the OpenTelemetry collector
    yq eval -i '.services.otel-collector.ports += [ "9464" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otel-collector.ports += [ "8888" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otel-collector.ports += [ "13133" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otel-collector.ports += [ "6060" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otel-collector.ports += [ "9080" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otel-collector.ports += [ "9411" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"
    yq eval -i '.services.otel-collector.ports += [ "9943" ]' "$SPLUNK_DOCKER_COMPOSE_PATH"

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

    # delete the opentelemetry-demo-otelcol objects
    yq eval -i 'select(.kind != "ServiceAccount" or .metadata.name != "opentelemetry-demo-otelcol")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "ConfigMap" or .metadata.name != "opentelemetry-demo-otelcol")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Service" or .metadata.name != "opentelemetry-demo-otelcol")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Deployment" or .metadata.name != "opentelemetry-demo-otelcol")' "$SPLUNK_K8S_PATH"

    # delete the grafana objects
    yq eval -i 'select(.kind != "ServiceAccount" or .metadata.name != "opentelemetry-demo-grafana")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "ServiceAccount" or .metadata.name != "opentelemetry-demo-grafana-test")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Secret" or .metadata.name != "opentelemetry-demo-grafana")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "ConfigMap" or .metadata.name != "opentelemetry-demo-grafana")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "ConfigMap" or .metadata.name != "opentelemetry-demo-grafana-test")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "ConfigMap" or .metadata.name != "opentelemetry-demo-grafana-dashboards")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "ClusterRole" or .metadata.name != "opentelemetry-demo-grafana-clusterrole")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "ClusterRoleBinding" or .metadata.name != "opentelemetry-demo-grafana-clusterrolebinding")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Role" or .metadata.name != "opentelemetry-demo-grafana")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "RoleBinding" or .metadata.name != "opentelemetry-demo-grafana")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Service" or .metadata.name != "opentelemetry-demo-grafana")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Deployment" or .metadata.name != "opentelemetry-demo-grafana")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Pod" or .metadata.name != "opentelemetry-demo-grafana-test")' "$SPLUNK_K8S_PATH"

    # delete the jaeger objects
    yq eval -i 'select(.kind != "ServiceAccount" or .metadata.name != "opentelemetry-demo-jaeger")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Service" or .metadata.name != "opentelemetry-demo-jaeger-agent")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Service" or .metadata.name != "opentelemetry-demo-jaeger-collector")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Service" or .metadata.name != "opentelemetry-demo-jaeger-query")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Deployment" or .metadata.name != "opentelemetry-demo-jaeger")' "$SPLUNK_K8S_PATH"

    # delete the prometheus objects
    yq eval -i 'select(.kind != "ServiceAccount" or .metadata.name != "opentelemetry-demo-prometheus-server")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "ConfigMap" or .metadata.name != "opentelemetry-demo-prometheus-server")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "ClusterRole" or .metadata.name != "opentelemetry-demo-prometheus-server")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "ClusterRoleBinding" or .metadata.name != "opentelemetry-demo-prometheus-server")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Service" or .metadata.name != "opentelemetry-demo-prometheus-server")' "$SPLUNK_K8S_PATH"
    yq eval -i 'select(.kind != "Deployment" or .metadata.name != "opentelemetry-demo-prometheus-server")' "$SPLUNK_K8S_PATH"

    # update the memory setting for various containers due to OOM issues
    yq eval -i '(select(.spec.template.spec.containers) | .spec.template.spec.containers.[] | select(.name == "frontendproxy")).resources.limits.memory |= "100Mi" ' "$SPLUNK_K8S_PATH"
    yq eval -i '(select(.spec.template.spec.containers) | .spec.template.spec.containers.[] | select(.name == "frontend")).resources.limits.memory |= "400Mi" ' "$SPLUNK_K8S_PATH"
    yq eval -i '(select(.spec.template.spec.containers) | .spec.template.spec.containers.[] | select(.name == "loadgenerator")).resources.limits.memory |= "1500Mi" ' "$SPLUNK_K8S_PATH"
    yq eval -i '(select(.spec.template.spec.containers) | .spec.template.spec.containers.[] | select(.name == "emailservice")).resources.limits.memory |= "200Mi" ' "$SPLUNK_K8S_PATH"
    yq eval -i '(select(.spec.template.spec.containers) | .spec.template.spec.containers.[] | select(.name == "flagd")).resources.limits.memory |= "150Mi" ' "$SPLUNK_K8S_PATH"
    yq eval -i '(select(.spec.template.spec.containers) | .spec.template.spec.containers.[] | select(.name == "flagd-ui")).resources.limits.memory |= "150Mi" ' "$SPLUNK_K8S_PATH"

    # add a cpu limit for the load generator container due to excessive CPU usage
    yq eval -i '(select(.spec.template.spec.containers) | .spec.template.spec.containers.[] | select(.name == "loadgenerator")).resources.limits.cpu |= "1" ' "$SPLUNK_K8S_PATH"

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
