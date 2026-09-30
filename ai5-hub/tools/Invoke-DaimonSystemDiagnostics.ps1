<#
DAIMON Tool Executor: SYSTEM_DIAGNOSTICS
Exact allowed operation : read-only host diagnostics (hostname, RAM, git-process count/RAM).
                          No arguments accepted beyond -BusRoot; nothing is ever written outside it.
Input schema            : none (this tool takes no task-specific input; it reports host state).
Path/scope restriction  : read-only Windows queries (Win32_OperatingSystem, Get-Process); writes only
                          <bus_root>\results\SYSTEM_DIAGNOSTICS-<timestamp>.json.
Timeout                 : n/a (synchronous WMI/CIM queries, no external process spawned).
Exit codes              : 0 = report written. Never non-zero (read-only, cannot meaningfully fail).
Result/Receipt/Evidence : writes <bus_root>\results\SYSTEM_DIAGNOSTICS-<timestamp>.json and prints it.
#>
param(
  [string]$BusRoot = 'C:\Users\teppe\.local\daimon\bus'
)
$ErrorActionPreference = 'Stop'

$os = Get-CimInstance Win32_OperatingSystem
$gitProcs = @(Get-Process -Name git,git-remote-https -ErrorAction SilentlyContinue)
$gitRamMiB = [math]::Round(($gitProcs | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 1)

$report = [ordered]@{
  schema_version    = '1.0'
  generated_at      = [DateTimeOffset]::Now.ToString('o')
  hostname          = $env:COMPUTERNAME
  free_ram_gib      = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
  total_ram_gib     = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
  git_process_count = $gitProcs.Count
  git_process_ram_mib = $gitRamMiB
}

$resultDir = Join-Path $BusRoot 'results'
New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$path = Join-Path $resultDir "SYSTEM_DIAGNOSTICS-$stamp.json"
$json = $report | ConvertTo-Json -Depth 5
$json | Set-Content -LiteralPath $path -Encoding utf8
$json | Write-Output
exit 0
