# gh-copilot-byom

A starter repository that provisions an isolated Azure environment for using **Bring-Your-Own-Model (BYOM)** with GitHub Copilot.

## What gets deployed

| Resource | Details |
|---|---|
| **Virtual Network** | New VNet (or reuse existing via `vnet_id`) with three subnets: `dev-vms`, `ai-foundry`, `AzureBastionSubnet` |
| **Azure Bastion** | Managed bastion host + static public IP – lets you RDP/SSH to VMs without exposing them to the internet |
| **Windows Server 2022 VM** | Virtual Machine for Developers in the `dev-vms` subnet – pre-loaded with ML tooling (Python, Jupyter, CUDA, etc.) |
| **Azure OpenAI** | Cognitive Services account with a **GPT-51** model deployment |
| **AI Foundry Hub** | Azure AI Foundry Hub wired to the OpenAI service, backed by a Storage Account and Key Vault |

## Repository layout

```
.
├── infra/                        # Terraform root module
│   ├── providers.tf              # AzureRM + Random providers
│   ├── variables.tf              # All input variables (incl. vnet_id)
│   ├── main.tf                   # Module composition
│   ├── outputs.tf                # Key resource IDs and endpoints
│   ├── terraform.tfvars.example  # Copy → terraform.tfvars and fill in
│   └── modules/
│       ├── network/              # VNet / subnets (conditional create)
│       ├── bastion/              # Azure Bastion host + public IP
│       ├── data-science-vm/      # Ubuntu DSVM
│       └── ai-foundry/           # OpenAI (GPT-4o) + AI Foundry Hub
├── packer/
│   ├── dsvm-copilot.pkr.hcl     # Packer template – Windows Server 2022 image
│   └── scripts/
│       └── install-vscode.ps1    # VS Code installer provisioner script
├── scripts/
│   ├── build-image.sh            # Build the Packer VM image (wrapper)
│   ├── create_rg.sh              # Create the Azure Resource Group
│   └── deploy.sh                 # terraform init + plan/apply/destroy
└── vm-scripts/
    └── install-github-copilot-cli-windows.ps1  # Install GitHub Copilot CLI on Windows
```

## Prerequisites

- [Terraform ≥ 1.5](https://developer.hashicorp.com/terraform/downloads)
- [Packer ≥ 1.15.1](https://developer.hashicorp.com/packer/install)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) – logged in (`az login` or `az login --use-device-code` for Government)
- An Azure subscription with **Contributor** rights (Azure Commercial or Azure Government)
- GPT-51 quota in your target region (request via [Azure OpenAI Studio](https://oai.azure.com/))

## Cloud environment support

All scripts and Terraform templates support both **Azure Commercial** (`AzureCloud`) and **Azure Government** (`AzureUSGovernment`).  
The default is **Azure Government** to maintain backward compatibility.

| Cloud | CLI flag | Terraform `azure_environment` | Default location |
|---|---|---|---|
| Azure Government | `--cloud AzureUSGovernment` | `usgovernment` | `usgovarizona` |
| Azure Commercial | `--cloud AzureCloud` | `public` | `eastus` |

Each script calls `az cloud set --name <cloud>` automatically before checking authentication, so you can switch clouds without running it manually.

## VS Code Tasks

This repo includes pre-configured VS Code tasks (`.vscode/tasks.json`) so you can run common operations directly from the editor via **Terminal → Run Task** or `Ctrl+Shift+P` → **Tasks: Run Task**:

| Task | Description |
|---|---|
| **Terraform: Create tfvars file** | Copies `terraform.tfvars.example` → `terraform.tfvars` |
| **Packer: Build Image [Azure Government]** | Runs `build-image.sh --cloud AzureUSGovernment` (prompts for the WinRM password) **NOTE: This can take up to 10 minutes to run.** |
| **Packer: Build Image [Azure Commercial]** | Runs `build-image.sh --cloud AzureCloud` (prompts for the WinRM password) **NOTE: This can take up to 10 minutes to run.** |
| **Terraform: Deploy - Plan [Azure Government]** | Runs `deploy.sh --cloud AzureUSGovernment -a plan` |
| **Terraform: Deploy - Plan [Azure Commercial]** | Runs `deploy.sh --cloud AzureCloud -a plan` |
| **Terraform: Deploy - Apply [Azure Government]** | Runs `deploy.sh --cloud AzureUSGovernment -a apply` |
| **Terraform: Deploy - Apply [Azure Commercial]** | Runs `deploy.sh --cloud AzureCloud -a apply` |
| **Terraform: Deploy - Destroy [Azure Government]** | Runs `deploy.sh --cloud AzureUSGovernment -a destroy` |
| **Terraform: Deploy - Destroy [Azure Commercial]** | Runs `deploy.sh --cloud AzureCloud -a destroy` |

## Quick start

### 1 - Run Packer to build Dev VM image

Currently we need to have a vm image with the following installed:

- VSCode
- Terminal
- NodeJS
- Github Copilot CLI

**NOTE: This script can take a few minutes to run**

The `build-image.sh` wrapper script handles `packer init`, `validate`, and `build` for you, with logging and pre-flight checks.

```bash
# Azure Government (default)
./scripts/build-image.sh --cloud AzureUSGovernment

# Azure Commercial
./scripts/build-image.sh --cloud AzureCloud -l eastus

# Prompted for WinRM password, or pass it explicitly
./scripts/build-image.sh -p "YourP@ssw0rd!"

# Custom resource group, location, and image name
./scripts/build-image.sh \
  --cloud AzureUSGovernment \
  -g rg-byom-prod \
  -l usgovarizona \
  -n my-custom-image \
  -p "YourP@ssw0rd!"

# Enable debug logging
./scripts/build-image.sh --cloud AzureUSGovernment --debug -p "YourP@ssw0rd!"
```

You can also set defaults via environment variables instead of flags:

```bash
# Azure Government
export AZURE_CLOUD=AzureUSGovernment
export RESOURCE_GROUP_NAME=rg-byom-dev
export LOCATION=usgovarizona
export IMAGE_NAME=dsvm-copilot-image
export VM_SIZE=Standard_DS3_v2
export COMMUNICATOR_PASSWORD="YourP@ssw0rd!"
./scripts/build-image.sh

# Azure Commercial
export AZURE_CLOUD=AzureCloud
export LOCATION=eastus
./scripts/build-image.sh
```

Build logs are saved to `packer/logs/`.

### 2 – Configure variables

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit infra/terraform.tfvars – at minimum set:
#   project_name
#   azure_environment  (usgovernment or public)
#   location           (e.g. usgovarizona or eastus)
```

### 3 – Plan & apply

```bash
# Azure Government – preview changes
./scripts/deploy.sh --cloud AzureUSGovernment -f infra/terraform.tfvars -a plan

# Azure Government – deploy
./scripts/deploy.sh --cloud AzureUSGovernment -f infra/terraform.tfvars

# Azure Commercial – preview changes
./scripts/deploy.sh --cloud AzureCloud -f infra/terraform.tfvars -a plan

# Azure Commercial – deploy
./scripts/deploy.sh --cloud AzureCloud -f infra/terraform.tfvars

# Unattended deploy (CI)
AUTO_APPROVE=true ./scripts/deploy.sh --cloud AzureUSGovernment -f infra/terraform.tfvars
```

### 4 – Connect to the Data Science VM

After `apply` completes:

```bash
# Get the VM's private IP and Bastion details
terraform -chdir=infra output dsvm_private_ip
terraform -chdir=infra output bastion_public_ip
```

Open the Azure Portal → **Virtual Machines** → select your DSVM → **Connect → Bastion**.

### 5 – Reuse an existing VNet

Set `vnet_id` in `terraform.tfvars` to the resource ID of your existing VNet.  
Terraform will create the three required subnets inside it instead of provisioning a new VNet:

```hcl
vnet_id = "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<name>"
```

### 6 – Tear down

```bash
# Azure Government
./scripts/deploy.sh --cloud AzureUSGovernment -f infra/terraform.tfvars -a destroy

# Azure Commercial
./scripts/deploy.sh --cloud AzureCloud -f infra/terraform.tfvars -a destroy
```

# Installing GitHub Copilot CLI

To install Github Copilot install with the following command:

```
npm install -g @github/copilot
```

# Running Github Copilot CLI

Run the following configuration for Github Copilot CLI:

```
export COPILOT_PROVIDER_BASE_URL=https://__YOUR_AOAI_RESOURCE__.openai.azure.us
export COPILOT_PROVIDER_TYPE=azure
export COPILOT_PROVIDER_API_KEY=__YOUR_KEY_HERE__
export COPILOT_MODEL=gpt-51
export COPILOT_WIRE_MODEL=gpt-51
export COPILOT_OFFLINE=true
export COPILOT_PROVIDER_MAX_PROMPT_TOKENS=128000
export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=4096
export COPILOT_PROVIDER_WIRE_API=responses
```

If you want to save this configuration, do so by running:

```
source ~/.bashrc
```

Then can start the CLI with the following:

```
copilot
```

## License

[MIT](LICENSE)
