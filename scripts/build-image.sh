#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# build-image.sh – Build the Packer VM image for gh-copilot-byom
#
# Usage:
#   ./scripts/build-image.sh [options]
#
# Options:
#   -g, --resource-group   Resource group for the image   (default: rg-byom-dev)
#   -l, --location         Azure region                   (default: usgovarizona)
#   -n, --image-name       Managed image name             (default: dsvm-copilot-image)
#   -s, --vm-size          Build VM size                  (default: Standard_DS3_v2)
#   -p, --password         WinRM password                 (prompted if not set)
#       --debug            Enable PACKER_LOG=1
#   -h, --help             Show this help text
#
# Environment variables (override defaults without passing flags):
#   RESOURCE_GROUP_NAME, LOCATION, IMAGE_NAME, VM_SIZE, COMMUNICATOR_PASSWORD
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKER_DIR="${SCRIPT_DIR}/../packer"
LOG_DIR="${SCRIPT_DIR}/../packer/logs"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-byom-dev}"
LOCATION="${LOCATION:-usgovarizona}"
IMAGE_NAME="${IMAGE_NAME:-dsvm-copilot-image}"
VM_SIZE="${VM_SIZE:-Standard_DS3_v2}"
COMMUNICATOR_PASSWORD="${COMMUNICATOR_PASSWORD:-}"
PACKER_DEBUG="${PACKER_DEBUG:-false}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
print_usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
}

log()  { printf "[%s] %s\n" "$(date -u +%H:%M:%SZ)" "$*"; }
err()  { log "ERROR: $*" >&2; }

cleanup() {
  local exit_code=$?
  if [[ ${exit_code} -ne 0 ]]; then
    err "Build failed with exit code ${exit_code}."
    if [[ -f "${LOG_FILE:-}" ]]; then
      err "Full log: ${LOG_FILE}"
      echo ""
      echo "--- Last 30 lines of log ---"
      tail -n 30 "${LOG_FILE}"
    fi
  fi
  exit "${exit_code}"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group)
      RESOURCE_GROUP_NAME="$2"; shift 2 ;;
    -l|--location)
      LOCATION="$2"; shift 2 ;;
    -n|--image-name)
      IMAGE_NAME="$2"; shift 2 ;;
    -s|--vm-size)
      VM_SIZE="$2"; shift 2 ;;
    -p|--password)
      COMMUNICATOR_PASSWORD="$2"; shift 2 ;;
    --debug)
      PACKER_DEBUG="true"; shift ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      err "Unknown option: $1"; print_usage; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if ! command -v packer &>/dev/null; then
  err "Packer is not installed. See https://developer.hashicorp.com/packer/downloads"
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

# Prompt for password if not supplied
if [[ -z "${COMMUNICATOR_PASSWORD}" ]]; then
  read -r -s -p "Enter WinRM password for the build VM: " COMMUNICATOR_PASSWORD
  echo ""
  if [[ -z "${COMMUNICATOR_PASSWORD}" ]]; then
    err "Password cannot be empty."
    exit 1
  fi
fi

# Verify the resource group exists
if ! az group show --name "${RESOURCE_GROUP_NAME}" &>/dev/null; then
  err "Resource group '${RESOURCE_GROUP_NAME}' does not exist. Create it first with ./scripts/create_rg.sh"
  exit 1
fi

# ---------------------------------------------------------------------------
# Prepare log directory
# ---------------------------------------------------------------------------
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/packer-build-$(date -u +%Y%m%dT%H%M%SZ).log"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
log "Subscription       : ${SUBSCRIPTION_ID}"
log "Resource group     : ${RESOURCE_GROUP_NAME}"
log "Location           : ${LOCATION}"
log "Image name         : ${IMAGE_NAME}"
log "VM size            : ${VM_SIZE}"
log "Packer directory   : ${PACKER_DIR}"
log "Log file           : ${LOG_FILE}"
echo ""

# ---------------------------------------------------------------------------
# Packer init
# ---------------------------------------------------------------------------
log "Running: packer init"
if ! packer init "${PACKER_DIR}" 2>&1 | tee -a "${LOG_FILE}"; then
  err "packer init failed."
  exit 1
fi

# ---------------------------------------------------------------------------
# Packer validate
# ---------------------------------------------------------------------------
log "Running: packer validate"
if ! packer validate \
  -var "resource_group_name=${RESOURCE_GROUP_NAME}" \
  -var "location=${LOCATION}" \
  -var "image_name=${IMAGE_NAME}" \
  -var "vm_size=${VM_SIZE}" \
  -var "communicator_password=${COMMUNICATOR_PASSWORD}" \
  "${PACKER_DIR}/dsvm-copilot.pkr.hcl" 2>&1 | tee -a "${LOG_FILE}"; then
  err "packer validate failed. Fix the template errors above before building."
  exit 1
fi
log "Template validated successfully."
echo ""

# ---------------------------------------------------------------------------
# Packer build
# ---------------------------------------------------------------------------
PACKER_ENV=()
if [[ "${PACKER_DEBUG}" == "true" ]]; then
  PACKER_ENV+=("PACKER_LOG=1" "PACKER_LOG_PATH=${LOG_DIR}/packer-debug-$(date -u +%Y%m%dT%H%M%SZ).log")
  log "Debug logging enabled."
fi

log "Running: packer build"
BUILD_START=$(date +%s)

env "${PACKER_ENV[@]+"${PACKER_ENV[@]}"}" \
  packer build \
    -color=true \
    -var "resource_group_name=${RESOURCE_GROUP_NAME}" \
    -var "location=${LOCATION}" \
    -var "image_name=${IMAGE_NAME}" \
    -var "vm_size=${VM_SIZE}" \
    -var "communicator_password=${COMMUNICATOR_PASSWORD}" \
    "${PACKER_DIR}/dsvm-copilot.pkr.hcl" 2>&1 | tee -a "${LOG_FILE}"

BUILD_EXIT=${PIPESTATUS[0]}
BUILD_END=$(date +%s)
BUILD_DURATION=$(( BUILD_END - BUILD_START ))

echo ""
if [[ ${BUILD_EXIT} -eq 0 ]]; then
  log "Image built successfully in $(( BUILD_DURATION / 60 ))m $(( BUILD_DURATION % 60 ))s."
  log "Image: ${IMAGE_NAME} in resource group ${RESOURCE_GROUP_NAME}"
else
  err "packer build failed after $(( BUILD_DURATION / 60 ))m $(( BUILD_DURATION % 60 ))s."
  exit ${BUILD_EXIT}
fi
