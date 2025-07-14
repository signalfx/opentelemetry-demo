#!/bin/bash
#

source /home/splunker/opentelemetry-demo/splunk/env
REGION=jp0

URL="https://ingest.${REGION}.signalfx.com/v2/event"
HEADER1="Content-Type: application/json"
HEADER2="X-SF-TOKEN: ${TOKEN}"

TIMESTAMP=$(date +%s)000
ENVIRONMENT=$1
SERVICE=$2
VERSION=$3

DATA=$(cat <<EOF
[
    {
        "category": "USER_DEFINED",
        "eventType": "Application Release",
        "dimensions": {
            "environment": "${ENVIRONMENT}",
            "service.name": "${SERVICE}",
            "service.version": "${VERSION}"
        },
        "timestamp": ${TIMESTAMP},
        "properties": {
            "release.git": "${GIT_REPO}/releases/tag/${VERSION}"
        }
    }
]
EOF
)

curl -XPOST ${URL} -H "${HEADER1}" -H "${HEADER2}" -d "${DATA}"
