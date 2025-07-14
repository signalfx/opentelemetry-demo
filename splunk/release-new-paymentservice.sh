#!/bin/bash
set -e

# usage: ./release-new-paymentservice.sh [new|revert] ENV SERVICE VERSION
MODE=$1
ENVIRONMENT=$2
SERVICE=$3
VERSION=$4

if [[ -z "$MODE" || -z "$ENVIRONMENT" || -z "$SERVICE" || -z "$VERSION" ]]; then
  echo "Usage: $0 [new|revert] ENV SERVICE VERSION"
  exit 1
fi

if [[ "$MODE" == "revert" ]]; then
  YAML="opentelemetry-demo.yaml"
  MARKER_VERSION="$VERSION"
  echo "[INFO] Reverting to previous version."
else
  YAML="opentelemetry-demo-with-paymenterror.yaml"
  MARKER_VERSION="$VERSION"
  echo "[INFO] Releasing new version with payment error."
fi
cd /home/splunker/opentelemetry-demo/splunk

# 1. Send deploy marker (apply前に実施)
echo "[INFO] Sending deploy marker: ENV=$ENVIRONMENT SERVICE=$SERVICE VERSION=$MARKER_VERSION"
/home/splunker/opentelemetry-demo/splunk/event_send.sh "$ENVIRONMENT" "$SERVICE" "$MARKER_VERSION"

# 2. Apply yaml
kubectl apply -f "$YAML"

# 3. Restart flagd deployment
kubectl rollout restart deployment/flagd

# 4. Wait for rollout of payment and flagd
echo "[INFO] Waiting for payment deployment to be ready..."
kubectl rollout status deployment/payment --timeout=120s
echo "[INFO] Waiting for flagd deployment to be ready..."
kubectl rollout status deployment/flagd --timeout=120s

# 5. Wait for all payment/flagd pods to be Running and Ready
for dep in payment flagd; do
  echo "[INFO] Checking pods for $dep..."
  while true; do
    NOT_READY=$(kubectl get pods -l app.kubernetes.io/name=$dep -o json \
      | jq -r '.items[] | select(.status.phase != "Running" or (.status.containerStatuses[]?.ready != true)) | .metadata.name')
    if [[ -z "$NOT_READY" ]]; then
      echo "[INFO] All $dep pods are Running and Ready."
      break
    else
      echo "[INFO] Waiting for pods: $NOT_READY"
      sleep 3
    fi
  done
done

echo "[INFO] Done."

