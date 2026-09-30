<#
DAIMON Tool Executor: LOCALHOST_HEALTH
Exact allowed operation : GET the local AI5 HUB command-center status endpoint. No other host,
                          no write verb, no request body.
Input schema            : none.
Path/scope restriction  : network access restricted to http://127.0.0.1:43125 only (hardcoded, not
                          parameterized, so this tool cannot be redirected to any other host).
                          Writes only <bus_root>\results\LOCALHOST_HEALTH-<timestamp>.json.
Timeout                 : 5s.
Exit codes              : 0 = reachable and JSON captured; 1 = unreachable or non-JSON response.
Result/Receipt/Evidence : writes <bus_root>\results\LOCALHOST_HEALTH-<timestamp>.json (raw response
                          plus fetch metadata) and prints a compact summary.
#>
param(
  [string]$BusRoot = 'C:\Users\teppe\.local\daimon\bus'
)
$ErrorActionPreference = 'Stop'
$resultDir = Join-Path $BusRoot 'results'
New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$path = Join-Path $resultDir "LOCALHOST_HEALTH-$stamp.json"

try {
  $resp = Invoke-WebRequest -Uri 'http://127.0.0.1:43125/api/command-center' -UseBasicParsing -TimeoutSec 5
  $body = $resp.Content | ConvertFrom-Json
  $summary = [ordered]@{
    schema_version = '1.0'; generated_at = [DateTimeOffset]::Now.ToString('o')
    reachable = $true; http_status = [int]$resp.StatusCode
    components = $body.components; approvalCount = $body.approvalCount
  }
  $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding utf8
  $summary | ConvertTo-Json -Depth 6 | Write-Output
  exit 0
} catch {
  $summary = [ordered]@{
    schema_version = '1.0'; generated_at = [DateTimeOffset]::Now.ToString('o')
    reachable = $false; error = $_.Exception.Message
  }
  $summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $path -Encoding utf8
  $summary | ConvertTo-Json -Depth 4 | Write-Output
  exit 1
}
