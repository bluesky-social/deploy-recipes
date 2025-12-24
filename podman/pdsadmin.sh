#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

PDSADMIN_BASE_URL="https://raw.githubusercontent.com/bluesky-social/pds/main/pdsadmin"
export PDS_ENV_FILE="/opt/pds/pds.env"
# Command to run.
COMMAND="${1:-help}"
shift || true

# we don't actually need root here since it only is required 

# Download the script, if it exists.
SCRIPT_URL="${PDSADMIN_BASE_URL}/${COMMAND}.sh"
SCRIPT_FILE="$(mktemp /tmp/pdsadmin.${COMMAND}.XXXXXX)"

if [[ "${COMMAND}" == "update" ]]; then
  echo "ERROR: self-update not supported via podman"
  exit 1
fi

if ! curl --fail --silent --show-error --location --output "${SCRIPT_FILE}" "${SCRIPT_URL}"; then
  echo "ERROR: ${COMMAND} not found"
  exit 2
fi

chmod +x "${SCRIPT_FILE}"
if "${SCRIPT_FILE}" "$@"; then
  rm -f "${SCRIPT_FILE}"
fi