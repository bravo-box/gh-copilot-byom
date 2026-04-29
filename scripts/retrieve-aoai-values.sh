#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# retrieve-aoai-values.sh – Retrieve GitHub Copilot BYOM environment variables
#                           from an existing Terraform deployment
#
# Usage:
#   ./retrieve-aoai-values.sh [options]
#
# Options:
#   -g, --resource-group  Resource group / project name  (default: rg-byom-dev)
#   -l, --location        Azure region                   (default: usgovarizona)
#   -f, --vars-file       Path to a .tfvars file
#   -h, --help            Show this help text
#
# Environment variables (override defaults without passing flags):
#   RESOURCE_GROUP_NAME, LOCATION, TF_VARS_FILE
#
# The script reads the Terraform state for an existing deployment and prints
# the 'export' commands needed to configure the GitHub Copilot CLI in your
# bash terminal.  It does not modify any infrastructure.
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/../infra"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-byom-dev}"
LOCATION="${LOCATION:-usgovarizona}"
TF_VARS_FILE="${TF_VARS_FILE:-}"

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
    -f|--vars-file)
      TF_VARS_FILE="$2"; shift 2 ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      err "Unknown option: $1"; print_usage; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if ! command -v terraform &>/dev/null; then
  err "Terraform is not installed. See https://developer.hashicorp.com/terraform/downloads"
  exit 1
fi

if ! command -v az &>/dev/null; then
  err "Azure CLI (az) is not installed. See https://docs.microsoft.com/cli/azure/install-azure-cli"
  exit 1
fi

if ! az account show &>/dev/null; then
  err "Not logged in to Azure CLI. Run 'az login' first."
  exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
log "Using subscription : ${SUBSCRIPTION_ID}"
log "Resource group     : ${RESOURCE_GROUP_NAME}"
log "Location           : ${LOCATION}"
log "Infra directory    : ${INFRA_DIR}"

# ---------------------------------------------------------------------------
# Build terraform argument list (used for init only – outputs need no vars)
# ---------------------------------------------------------------------------
TF_ARGS=()

if [[ -n "${TF_VARS_FILE}" ]]; then
  TF_VARS_FILE="$(cd "$(dirname "${TF_VARS_FILE}")" && pwd)/$(basename "${TF_VARS_FILE}")"
  TF_ARGS+=("-var-file=${TF_VARS_FILE}")
fi

TF_ARGS+=(
  "-var=project_name=${RESOURCE_GROUP_NAME}"
  "-var=location=${LOCATION}"
)

# ---------------------------------------------------------------------------
# Terraform init (required to read remote state) then retrieve outputs
# ---------------------------------------------------------------------------
cd "${INFRA_DIR}"

log "Running: terraform init"
terraform init -upgrade

log "Retrieving Copilot configuration from Terraform outputs..."

AOAI_ENDPOINT=$(terraform output -raw aoai_endpoint)
AOAI_KEY=$(terraform output -raw aoai_primary_key)
AOAI_DEPLOYMENT=$(terraform output -raw aoai_deployment_name)

echo ""
echo "# -----------------------------------------------------------------------"
echo "# GitHub Copilot BYOM – paste these into your bash terminal"
echo "# -----------------------------------------------------------------------"
echo "export COPILOT_PROVIDER_BASE_URL=${AOAI_ENDPOINT}"
echo "export COPILOT_PROVIDER_TYPE=azure"
echo "export COPILOT_PROVIDER_API_KEY=${AOAI_KEY}"
echo "export COPILOT_MODEL=${AOAI_DEPLOYMENT}"
echo "export COPILOT_WIRE_MODEL=${AOAI_DEPLOYMENT}"
echo "export COPILOT_OFFLINE=true"
echo "export COPILOT_PROVIDER_MAX_PROMPT_TOKENS=128000"
echo "export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=4096"
echo "export COPILOT_PROVIDER_WIRE_API=responses"
echo "# -----------------------------------------------------------------------"
echo "To save this configuration, run 'source ~/.bashrc'"
