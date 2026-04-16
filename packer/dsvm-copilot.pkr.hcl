# ---------------------------------------------------------------------------
# Packer template – Windows Server 2022 with VS Code, GitHub Copilot & CLI
#
# Builds a custom image from a plain Windows Server 2022 base, then installs
# Node.js, VS Code, the GitHub Copilot extension, and the Copilot CLI.
#
# Usage:
#   packer init   packer/
#   packer build  packer/dsvm-copilot.pkr.hcl
# ---------------------------------------------------------------------------

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = ">= 2.0.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "location" {
  type        = string
  default     = "usgovarizona"
  description = "Azure region for the build VM and resulting image."
}

variable "resource_group_name" {
  type        = string
  default     = "rg-byom-dev"
  description = "Resource group where the managed image will be stored."
}

variable "image_name" {
  type        = string
  default     = "dsvm-copilot-image"
  description = "Name of the resulting managed image."
}

variable "vm_size" {
  type        = string
  default     = "Standard_DS3_v2"
  description = "VM size used during the build."
}

variable "communicator_username" {
  type        = string
  default     = "dsadmin"
  description = "WinRM admin username for the build VM."
}

variable "communicator_password" {
  type        = string
  sensitive   = true
  description = "WinRM admin password for the build VM."
}

# ---------------------------------------------------------------------------
# Source – Plain Windows Server 2022 Datacenter (no marketplace plan needed)
# ---------------------------------------------------------------------------
source "azure-arm" "dsvm" {
  use_azure_cli_auth     = true
  cloud_environment_name = "USGovernment"
  location               = var.location

  # Standard Windows Server 2022 image – no plan / terms acceptance required
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-datacenter-g2"

  # Build VM settings
  vm_size                           = var.vm_size
  os_type                           = "Windows"
  communicator                      = "winrm"
  winrm_use_ssl                     = true
  winrm_insecure                    = true
  winrm_timeout                     = "10m"
  winrm_username                    = var.communicator_username
  winrm_password                    = var.communicator_password

  # Output image
  managed_image_name                = var.image_name
  managed_image_resource_group_name = var.resource_group_name

  azure_tags = {
    purpose = "gh-copilot-byom"
    built   = "packer"
  }
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
build {
  sources = ["source.azure-arm.dsvm"]

  # Install Node.js LTS (needed for npm / Copilot CLI)
  provisioner "powershell" {
    inline = [
      "Write-Host '>>> Installing Node.js LTS...'",
      "$installer = \"$Env:TEMP\\node-install.msi\"",
      "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12",
      "$url = 'https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi'",
      "$maxRetries = 5; $delay = 15",
      "for ($i = 1; $i -le $maxRetries; $i++) {",
      "  try {",
      "    Write-Host \"  Attempt $i of $maxRetries ...\"",
      "    Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing",
      "    break",
      "  } catch {",
      "    if ($i -eq $maxRetries) { Write-Error \"Download failed after $maxRetries attempts: $_\"; exit 1 }",
      "    Write-Host \"  Download failed, retrying in $${delay}s ...\"",
      "    Start-Sleep -Seconds $delay; $delay *= 2",
      "  }",
      "}",
      "Start-Process msiexec.exe -ArgumentList '/i', $installer, '/quiet', '/norestart' -Wait",
      "Remove-Item $installer -Force",
      "$Env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')",
      "Write-Host \"  node $(node --version)\"",
      "Write-Host \"  npm  $(npm --version)\"",
      "Write-Host '>>> Updating npm to latest (11.12.1)...'",
      "npm install -g npm@11.12.1",
      "Write-Host \"  npm  $(npm --version)\"",
    ]
  }

  # Install VS Code
  provisioner "powershell" {
    script = "${path.root}/scripts/install-vscode.ps1"
  }

  # Install Windows Terminal (via winget + Cascadia Mono font)
  provisioner "powershell" {
    inline = [
      "Write-Host '>>> Installing Chocolatey...'",
      "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))",
      "Write-Host '>>> Enable Global Confirmation...'",
      "choco feature enable -n allowGlobalConfirmation"
    ]
  }

  provisioner "powershell" {
    inline = [
      "Write-Host '>>> Installing Windows Terminal...'",
      "choco install microsoft-windows-terminal"
    ]
  }

  # Install the GitHub Copilot VS Code extension
  provisioner "powershell" {
    inline = [
      "Write-Host '>>> Installing GitHub Copilot extension...'",
      "$codePath = \"$Env:ProgramFiles\\Microsoft VS Code\\bin\\code.cmd\"",
      "& $codePath --install-extension GitHub.copilot --force 2>&1 | Write-Host",
      "& $codePath --install-extension GitHub.copilot-chat --force 2>&1 | Write-Host",
      "Write-Host '>>> Extensions installed.'",
    ]
  }

  # Install GitHub Copilot CLI
  provisioner "powershell" {
    inline = [
      "Write-Host '>>> Installing GitHub Copilot CLI...'",
      "$Env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')",
      "npm install -g @github/copilot",
      "Write-Host '>>> npm global prefix:' (npm prefix -g)",
      "Write-Host '>>> Copilot CLI version:'",
      "copilot --version",
    ]
  }

  # Generalise the image (sysprep)
  provisioner "powershell" {
    inline = [
      "Write-Host '>>> Running Sysprep...'",
      "& $Env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quit /quiet",
      "while ($true) {",
      "  $imageState = (Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State).ImageState",
      "  Write-Host \"  ImageState: $imageState\"",
      "  if ($imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { break }",
      "  Start-Sleep -Seconds 10",
      "}",
      "Write-Host '>>> Sysprep complete.'",
    ]
  }
}
