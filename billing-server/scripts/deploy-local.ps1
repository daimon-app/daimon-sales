$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $Root '.env'))) { throw 'Create billing-server/.env from .env.example and replace placeholder secrets first.' }
docker compose --file (Join-Path $Root 'compose.yaml') config --quiet
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose validation failed.' }
docker compose --file (Join-Path $Root 'compose.yaml') up --build --detach
if ($LASTEXITCODE -ne 0) { throw 'Local deployment failed.' }
