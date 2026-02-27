#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# create_rg.sh – Create an Azure Resource Group for the gh-copilot-byom infra
#
# Usage:
#   ./create_rg.sh [options]
#
# Options:
#   -g, --resource-group  Resource group name  (default: rg-gh-copilot-byom-dev)
#   -l, --location        Azure region         (default: usgovarizona)
#   -t, --tags            Additional space-separated key=value tags
#   -h, --help            Show this help text
#
# Environment variables (override defaults without passing flags):
#   RESOURCE_GROUP_NAME, LOCATION
# ---------------------------------------------------------------------------
set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-gh-copilot-byom-dev}"
LOCATION="${LOCATION:-usgovarizona}"
EXTRA_TAGS="${EXTRA_TAGS:-}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
print_usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
}

log()  { echo "[$(date -u +%H:%M:%SZ)] $*"; }
err()  { log "ERROR: $*" >&2; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group)
      RESOURCE_GROUP_NAME="$2"; shift 2 ;;
    -l|--location)
      LOCATION="$2"; shift 2 ;;
    -t|--tags)
      EXTRA_TAGS="$2"; shift 2 ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      err "Unknown option: $1"; print_usage; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if ! command -v az &>/dev/null; then
  err "Azure CLI (az) is not installed. See https://docs.microsoft.com/cli/azure/install-azure-cli"
  exit 1
fi

if ! az account show &>/dev/null; then
  err "Not logged in to Azure CLI. Run 'az login' first."
  exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
log "Using subscription: ${SUBSCRIPTION_ID}"

# ---------------------------------------------------------------------------
# Create (or confirm existence of) the resource group
# ---------------------------------------------------------------------------
DEFAULT_TAGS="project=gh-copilot-byom environment=dev managed_by=terraform"
ALL_TAGS="${DEFAULT_TAGS} ${EXTRA_TAGS}"

log "Resource group : ${RESOURCE_GROUP_NAME}"
log "Location       : ${LOCATION}"

if az group show --name "${RESOURCE_GROUP_NAME}" &>/dev/null; then
  log "Resource group '${RESOURCE_GROUP_NAME}' already exists – skipping creation."
else
  log "Creating resource group '${RESOURCE_GROUP_NAME}'..."
  # shellcheck disable=SC2086
  az group create \
    --name     "${RESOURCE_GROUP_NAME}" \
    --location "${LOCATION}" \
    --tags     ${ALL_TAGS} \
    --output   table
  log "Resource group created successfully."
fi
