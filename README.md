# gh-copilot-byom

A starter repository that provisions an isolated Azure environment for using **Bring-Your-Own-Model (BYOM)** with GitHub Copilot.

## What gets deployed

| Resource | Details |
|---|---|
| **Virtual Network** | New VNet (or reuse existing via `vnet_id`) with three subnets: `dev-vms`, `ai-foundry`, `AzureBastionSubnet` |
| **Azure Bastion** | Managed bastion host + static public IP – lets you RDP/SSH to VMs without exposing them to the internet |
| **Data Science VM** | Ubuntu 22.04 DSVM in the `dev-vms` subnet – pre-loaded with ML tooling (Python, Jupyter, CUDA, etc.) |
| **Azure OpenAI** | Cognitive Services account with a **GPT-4o** model deployment |
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
└── scripts/
    ├── create_rg.sh              # Create the Azure Resource Group
    └── deploy.sh                 # terraform init + plan/apply/destroy
```

## Prerequisites

- [Terraform ≥ 1.5](https://developer.hashicorp.com/terraform/downloads)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) – logged in (`az login`)
- An Azure subscription with **Contributor** rights
- GPT-4o quota in your target region (request via [Azure OpenAI Studio](https://oai.azure.com/))

## Quick start

### 1 – Create the Resource Group

```bash
# defaults: name=rg-byom-dev, location=eastus
./scripts/create_rg.sh

# custom name / region
./scripts/create_rg.sh -g rg-byom-prod -l westus2
```

### 2 – Configure variables

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit infra/terraform.tfvars – at minimum set:
#   resource_group_name  and  ssh_public_key
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

## Accepting the DSVM marketplace image terms

The Ubuntu DSVM is a paid marketplace image. Accept the terms **once per subscription** before the first deploy:

```bash
az vm image terms accept \
  --publisher microsoft-dsvm \
  --offer     ubuntu-2204 \
  --plan      2204
```

## License

[MIT](LICENSE)
