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
│   ├── deploy.sh                 # terraform init + plan/apply/destroy
│   └── retrieve-aoai-values.sh  # Retrieve Copilot env vars from an existing deployment
└── vm-scripts/
    └── install-github-copilot-cli-windows.ps1  # Install GitHub Copilot CLI on Windows
```

## Prerequisites

- [Terraform ≥ 1.5](https://developer.hashicorp.com/terraform/downloads)
- [Packer ≥ 1.15.1](https://developer.hashicorp.com/packer/install)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) – logged in (`az login`)
- An Azure subscription with **Contributor** rights
- GPT-51 quota in your target region (request via [Azure OpenAI Studio](https://oai.azure.com/))

## VS Code Tasks

This repo includes pre-configured VS Code tasks (`.vscode/tasks.json`) so you can run common operations directly from the editor via **Terminal → Run Task** or `Ctrl+Shift+P` → **Tasks: Run Task**:

| Task | Description |
|---|---|
| **Terraform: Create tfvars file** | Copies `terraform.tfvars.example` → `terraform.tfvars` |
| **Packer: Build Image** | Runs `build-image.sh` (prompts for the WinRM password) **NOTE: This can take up to 10 minutes to run.** |
| **Terraform: Deploy - Plan** | Runs `deploy.sh -a plan` |
| **Terraform: Deploy - Apply** | Runs `deploy.sh -a apply` |
| **Terraform: Deploy - Destroy** | Runs `deploy.sh -a destroy` |
| **Terraform: Retrieve AOAI Values** | Runs `retrieve-aoai-values.sh` to print the Copilot env vars for an existing deployment |

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
# Using defaults (rg-byom-dev, usgovarizona, dsvm-copilot-image)
./scripts/build-image.sh

# Prompted for WinRM password, or pass it explicitly
./scripts/build-image.sh -p "YourP@ssw0rd!"

# Custom resource group, location, and image name
./scripts/build-image.sh \
  -g rg-byom-prod \
  -l usgovarizona \
  -n my-custom-image \
  -p "YourP@ssw0rd!"

# Enable debug logging
./scripts/build-image.sh --debug -p "YourP@ssw0rd!"
```

You can also set defaults via environment variables instead of flags:

```bash
export RESOURCE_GROUP_NAME=rg-byom-dev
export LOCATION=usgovarizona
export IMAGE_NAME=dsvm-copilot-image
export VM_SIZE=Standard_DS3_v2
export COMMUNICATOR_PASSWORD="YourP@ssw0rd!"
./scripts/build-image.sh
```

Build logs are saved to `packer/logs/`.

### 2 – Configure variables

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit infra/terraform.tfvars – at minimum set:
#   resource_group_name
```

### 3 – Plan & apply

```bash
# Preview changes
./scripts/deploy.sh -f infra/terraform.tfvars -a plan

# Deploy
./scripts/deploy.sh -f infra/terraform.tfvars

# Unattended deploy (CI)
AUTO_APPROVE=true ./scripts/deploy.sh -f infra/terraform.tfvars
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
./scripts/deploy.sh -f infra/terraform.tfvars -a destroy
```

### 7 – Retrieve AOAI values for an existing deployment

If you need to re-fetch the GitHub Copilot environment variables from an already-deployed environment (e.g. on a new terminal session or a different machine), use the `retrieve-aoai-values.sh` script:

```bash
# Using defaults (resource group: rg-byom-dev, location: usgovarizona)
./scripts/retrieve-aoai-values.sh

# Specify a resource group and vars file
./scripts/retrieve-aoai-values.sh -g my-resource-group -f infra/terraform.tfvars
```

The script connects to the existing Terraform state, reads the Azure OpenAI endpoint, API key, and model deployment name, then prints the `export` commands ready to paste into your terminal:

```text
# -----------------------------------------------------------------------
# GitHub Copilot BYOM – paste these into your bash terminal
# -----------------------------------------------------------------------
export COPILOT_PROVIDER_BASE_URL=https://<your-aoai-resource>.openai.azure.us/
export COPILOT_PROVIDER_TYPE=azure
export COPILOT_PROVIDER_API_KEY=<your-key>
export COPILOT_MODEL=gpt-51
export COPILOT_WIRE_MODEL=gpt-51
export COPILOT_OFFLINE=true
export COPILOT_PROVIDER_MAX_PROMPT_TOKENS=128000
export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=4096
export COPILOT_PROVIDER_WIRE_API=responses
# -----------------------------------------------------------------------
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
