# gh-copilot-byom

A starter repository that provisions an isolated Azure environment for using **Bring-Your-Own-Model (BYOM)** with GitHub Copilot – both CLI and VS Code extension.

## What gets deployed

| Resource | Details |
|---|---|
| **Virtual Network** | VNet with subnets: `virtual-machines`, `aoai`, `storage`, `AzureBastionSubnet` |
| **Azure Bastion** | Managed bastion host + static public IP – lets you RDP/SSH to VMs without exposing them to the internet |
| **Windows Server 2022 VM** | Custom Packer image with VS Code 1.122, Node.js, Git, GitHub Copilot CLI, and pre-configured `chatLanguageModels.json` for BYOM |
| **Azure OpenAI** | Cognitive Services account with a **GPT-5.1** model deployment |
| **Storage Account** | Blob storage with private endpoint |

## Repository layout

```
.
├── infra/                        # Terraform root module
│   ├── providers.tf              # AzureRM provider
│   ├── variables.tf              # All input variables (incl. deploy_vm toggle)
│   ├── main.tf                   # Resource definitions (VM conditional)
│   ├── outputs.tf                # Key resource IDs, endpoints, and aoai_responses_url
│   └── terraform.tfvars.example  # Copy → terraform.tfvars and fill in
├── packer/
│   ├── dsvm-copilot.pkr.hcl     # Packer template – Windows Server 2022 image
│   └── scripts/
│       └── install-vscode.ps1    # VS Code 1.122 installer
├── scripts/
│   ├── build-image.sh            # Build the Packer VM image (wrapper)
│   ├── create_rg.sh              # Create the Azure Resource Group
│   ├── deploy.sh                 # terraform init + plan/apply/destroy
│   └── retrieve-aoai-values.sh   # Retrieve Copilot env vars from an existing deployment
└── .vscode/
    └── tasks.json                # Pre-configured VS Code tasks
```

## Prerequisites

- [Terraform ≥ 1.5](https://developer.hashicorp.com/terraform/downloads)
- [Packer ≥ 1.15.1](https://developer.hashicorp.com/packer/install)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) – logged in (`az login`)
- An Azure subscription with **Contributor** rights
- GPT-5.1 quota in your target region (request via [Azure OpenAI Studio](https://oai.azure.com/))

## VS Code Tasks

This repo includes pre-configured VS Code tasks (`.vscode/tasks.json`) so you can run common operations directly from the editor via **Terminal → Run Task** or `Ctrl+Shift+P` → **Tasks: Run Task**:

| Task | Description |
|---|---|
| **Terraform: Create tfvars file** | Copies `terraform.tfvars.example` → `terraform.tfvars` |
| **Terraform: Deploy Infra Only (no VM)** | Deploys networking + AOAI without the VM (phase 1) |
| **Packer: Build Image** | Runs `build-image.sh` – auto-retrieves AOAI URL from Terraform state |
| **Terraform: Deploy - Plan** | Runs `deploy.sh -a plan` |
| **Terraform: Deploy - Apply** | Runs `deploy.sh -a apply` (full deploy including VM) |
| **Terraform: Deploy - Destroy** | Runs `deploy.sh -a destroy` |
| **Terraform: Retrieve AOAI Values** | Prints Copilot env vars for an existing deployment |

## Quick start

### Two-phase deployment workflow

The recommended workflow deploys infrastructure first (without the VM), builds the Packer image with the AOAI endpoint baked in, then re-deploys with the VM using the custom image:

```bash
# Phase 1: Deploy infra only (networking + AOAI, no VM)
TF_VAR_deploy_vm=false ./scripts/deploy.sh -f infra/terraform.tfvars --auto-approve

# Phase 2: Build the Packer image (AOAI URL auto-retrieved from Terraform state)
./scripts/build-image.sh -p "YourP@ssw0rd!"

# Phase 3: Deploy with VM using the custom image
# (build-image.sh auto-updates terraform.tfvars with custom_vm_image_id)
./scripts/deploy.sh -f infra/terraform.tfvars --auto-approve
```

### 1 - Run Packer to build Dev VM image

The Packer image includes:

- VS Code 1.122 (pinned)
- Windows Terminal
- Node.js LTS + npm
- Git for Windows (Git Bash as default terminal)
- PowerShell Core
- GitHub Copilot CLI
- `chatLanguageModels.json` pre-configured for Azure Government BYOM

The `build-image.sh` wrapper script handles `packer init`, `validate`, and `build` for you, with logging and pre-flight checks.

```bash
# Using defaults (auto-retrieves AOAI URL from Terraform state)
./scripts/build-image.sh -p "YourP@ssw0rd!"

# Explicit AOAI URL
./scripts/build-image.sh -p "YourP@ssw0rd!" -u "https://my-aoai.cognitiveservices.azure.us/openai/responses?api-version=2025-04-01-preview"

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
export RESOURCE_GROUP_NAME=rg-byom-dev-vm-images
export LOCATION=usgovarizona
export IMAGE_NAME=dsvm-copilot-image
export VM_SIZE=Standard_DS3_v2
export COMMUNICATOR_PASSWORD="YourP@ssw0rd!"
export AOAI_ENDPOINT_URL="https://my-aoai.cognitiveservices.azure.us/openai/responses?api-version=2025-04-01-preview"
./scripts/build-image.sh
```

Build logs are saved to `packer/logs/`.

### 2 – Configure variables

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit infra/terraform.tfvars – at minimum set:
#   project_name
#   vm_admin_password (when deploy_vm = true)
```

### 3 – Plan & apply

```bash
# Preview changes
./scripts/deploy.sh -f infra/terraform.tfvars -a plan

# Deploy (full, including VM)
./scripts/deploy.sh -f infra/terraform.tfvars

# Deploy infra only (no VM – for image build workflow)
TF_VAR_deploy_vm=false ./scripts/deploy.sh -f infra/terraform.tfvars

# Unattended deploy (CI)
AUTO_APPROVE=true ./scripts/deploy.sh -f infra/terraform.tfvars
```

### 4 – Connect to the Data Science VM

After `apply` completes:

```bash
# Get the VM's private IP and Bastion details
terraform -chdir=infra output vm_private_ip
terraform -chdir=infra output bastion_public_ip
```

Open the Azure Portal → **Virtual Machines** → select your VM → **Connect → Bastion**.

### 5 – Tear down

```bash
./scripts/deploy.sh -f infra/terraform.tfvars -a destroy
```

### 6 – Retrieve AOAI values for an existing deployment

If you need to re-fetch the GitHub Copilot environment variables from an already-deployed environment:

```bash
./scripts/retrieve-aoai-values.sh -f infra/terraform.tfvars
```

## VS Code BYOM – chatLanguageModels.json

The Packer image bakes a `chatLanguageModels.json` file into the VS Code user profile at:
- `%APPDATA%\Code\User\chatLanguageModels.json`

This configures the GitHub Copilot extension to use your Azure Government OpenAI models directly. After first login, update the `apiKey` field with your actual AOAI key:

```json
[
  {
    "name": "Azure Government",
    "vendor": "azure",
    "apiKey": "<your-AOAI-API-key-here>",
    "models": [
      {
        "id": "gpt-5.1",
        "name": "GPT 5.1 (Gov Direct Key)",
        "url": "https://<your-aoai>.cognitiveservices.azure.us/openai/responses?api-version=2025-04-01-preview",
        "toolCalling": true,
        "vision": true,
        "thinking": true,
        "supportsReasoningEffort": ["none", "low", "medium", "high"],
        "reasoningEffortFormat": "responses",
        "maxInputTokens": 272000,
        "maxOutputTokens": 128000
      },
      {
        "id": "gpt-4.1",
        "name": "GPT 4.1 (Gov Direct Key)",
        "url": "https://<your-aoai>.cognitiveservices.azure.us/openai/responses?api-version=2025-04-01-preview",
        "toolCalling": true,
        "vision": true,
        "maxInputTokens": 128000,
        "maxOutputTokens": 32768
      },
      {
        "id": "gpt-4.1-mini",
        "name": "GPT 4.1 Mini (Gov Direct Key)",
        "url": "https://<your-aoai>.cognitiveservices.azure.us/openai/responses?api-version=2025-04-01-preview",
        "toolCalling": true,
        "vision": true,
        "maxInputTokens": 128000,
        "maxOutputTokens": 32768
      }
    ],
    "settings": {
      "gpt-5.1": {
        "reasoningEffort": "high"
      }
    }
  }
]
```

## GitHub Copilot CLI

To install GitHub Copilot CLI (already included in the Packer image):

```bash
npm install -g @github/copilot
```

Configure and run:

```bash
export COPILOT_PROVIDER_BASE_URL=https://__YOUR_AOAI_RESOURCE__.openai.azure.us
export COPILOT_PROVIDER_TYPE=azure
export COPILOT_PROVIDER_API_KEY=__YOUR_KEY_HERE__
export COPILOT_MODEL=gpt-51
export COPILOT_WIRE_MODEL=gpt-51
export COPILOT_OFFLINE=true
export COPILOT_PROVIDER_MAX_PROMPT_TOKENS=128000
export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=4096
export COPILOT_PROVIDER_WIRE_API=responses

copilot
```

## License

[MIT](LICENSE)
