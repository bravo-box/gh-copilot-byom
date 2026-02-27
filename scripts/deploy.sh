#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# deploy.sh – Initialize and deploy the gh-copilot-byom Terraform infrastructure
#
# Usage:
#   ./deploy.sh [options]
#
# Options:
#   -g, --resource-group  Resource group name        (default: rg-gh-copilot-byom-dev)
#   -l, --location        Azure region               (default: usgovarizona)
#   -f, --vars-file       Path to a .tfvars file
#   -a, --action          plan | apply | destroy     (default: apply)
#       --auto-approve    Skip interactive confirmation
#   -h, --help            Show this help text
#
# Environment variables (override defaults without passing flags):
#   RESOURCE_GROUP_NAME, LOCATION, TF_VARS_FILE, ACTION, AUTO_APPROVE
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/../infra"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-gh-copilot-byom-dev}"
LOCATION="${LOCATION:-usgovarizona}"
TF_VARS_FILE="${TF_VARS_FILE:-}"
ACTION="${ACTION:-apply}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

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
    -a|--action)
      ACTION="$2"; shift 2 ;;
    --auto-approve)
      AUTO_APPROVE="true"; shift ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      err "Unknown option: $1"; print_usage; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate action
# ---------------------------------------------------------------------------
if [[ ! "${ACTION}" =~ ^(plan|apply|destroy)$ ]]; then
  err "Invalid action '${ACTION}'. Must be one of: plan, apply, destroy."
  exit 1
fi

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
log "Action             : ${ACTION}"
log "Infra directory    : ${INFRA_DIR}"

# ---------------------------------------------------------------------------
# Build terraform argument list
# ---------------------------------------------------------------------------
TF_ARGS=()

if [[ -n "${TF_VARS_FILE}" ]]; then
  # Convert to absolute path in case it's relative
  TF_VARS_FILE="$(cd "$(dirname "${TF_VARS_FILE}")" && pwd)/$(basename "${TF_VARS_FILE}")"
  TF_ARGS+=("-var-file=${TF_VARS_FILE}")
fi

TF_ARGS+=(
  "-var=resource_group_name=${RESOURCE_GROUP_NAME}"
  "-var=location=${LOCATION}"
)

if [[ "${AUTO_APPROVE}" == "true" && "${ACTION}" != "plan" ]]; then
  TF_ARGS+=("-auto-approve")
fi

# ---------------------------------------------------------------------------
# Terraform init + selected action
# ---------------------------------------------------------------------------
cd "${INFRA_DIR}"

log "Running: terraform init"
terraform init -upgrade

log "Running: terraform ${ACTION}"
terraform "${ACTION}" "${TF_ARGS[@]}"

if [[ "${ACTION}" == "apply" ]]; then
  log "Deployment complete. Run 'terraform output' in the infra/ directory to see resource details."
fi
