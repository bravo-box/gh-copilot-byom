$ErrorActionPreference = 'Stop'

Write-Host 'Installing GitHub CLI via winget...'
winget install --id GitHub.cli --source winget --accept-package-agreements --accept-source-agreements

Write-Host 'Installing GitHub Copilot CLI extension...'
gh extension install github/gh-copilot

Write-Host 'GitHub Copilot CLI installed successfully.'
Write-Host "If not already authenticated, run: gh auth login"
