npm install -g @github/copilot
[Environment]::SetEnvironmentVariable("Path", "$([Environment]::GetEnvironmentVariable('Path', 'Machine'));$npmPrefix", "Machine")

$env:COPILOT_PROVIDER_TYPE = "azure"
$env:COPILOT_PROVIDER_BASE_URL = "__REPLACE_WITH_YOUR_AOAI_ENDPOINT__"
$env:COPILOT_PROVIDER_API_KEY = "__REPLACE_WITH_YOUR_AOAI_KEY__"
$env:COPILOT_MODEL = "gpt-51"
$env:COPILOT_OFFLINE = true

copilot --version