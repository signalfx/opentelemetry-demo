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

# ---- OpenTelemetry Demo Update ----
update_root_readme

