$ErrorActionPreference = 'Stop'

try {
    Write-Host 'Installing GitHub CLI via winget...'
    winget install --id GitHub.cli --source winget --accept-package-agreements --accept-source-agreements
}
catch {
    throw "Failed to install GitHub CLI with winget. $_"
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) was not found in PATH after installation. Open a new PowerShell session and run this script again."
}

try {
    Write-Host 'Installing GitHub Copilot CLI extension...'
    gh extension install github/gh-copilot
}
catch {
    throw "Failed to install GitHub Copilot CLI extension. $_"
}

Write-Host 'GitHub Copilot CLI installed successfully.'
Write-Host "If not already authenticated, run: gh auth login"
