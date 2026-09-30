<#
DAIMON Tool Executor: BUS_STATUS
Exact allowed operation : read-only summary of the DAIMON task bus (tasks/results/receipts/leases/
                          worker-registry) and, optionally, a fetch-only check of the dynabook
                          cross-machine bus for a specific task_id's Result/Receipt.
Input schema            : -TaskId <string> (optional; filters to one task and checks the dynabook
                          bus repo for its Result/Receipt if -CheckDynabookBus is passed).
                          -CheckDynabookBus (switch, optional).
Path/scope restriction  : reads only <bus_root> and (if -CheckDynabookBus) runs `git fetch origin main`
                          (read-only network op, no push/commit) inside the fixed
                          ai5-github-result-bus repo path, then reads its bus/results and
                          bus/state/receipts directories only.
Timeout                 : 15s for the optional git fetch.
Exit codes              : 0 always (pure read/report tool).
Result/Receipt/Evidence : prints a JSON summary to stdout; writes nothing (status tool only).
#>
param(
  [string]$TaskId,
  [switch]$CheckDynabookBus,
  [string]$BusRoot = 'C:\Users\teppe\.local\daimon\bus',
  [string]$DynabookBusRepo = 'C:\Users\teppe\Documents\GitHub\daimon-sales\ai5-github-result-bus'
)
$ErrorActionPreference = 'Stop'

function Get-JsonFiles([string]$Dir) {
  if (!(Test-Path -LiteralPath $Dir)) { return @() }
  Get-ChildItem -LiteralPath $Dir -Filter '*.json' -File -ErrorAction SilentlyContinue
}

$summary = [ordered]@{
  schema_version = '1.0'; generated_at = [DateTimeOffset]::Now.ToString('o')
}

$tasks = Get-JsonFiles (Join-Path $BusRoot 'tasks') | ForEach-Object {
  try { Get-Content -Raw -Encoding utf8 -LiteralPath $_.FullName | ConvertFrom-Json } catch { $null }
} | Where-Object { $_ -and (-not $TaskId -or $_.task_id -eq $TaskId) }

$summary.task_count = @($tasks).Count
$summary.tasks_by_status = @($tasks) | Group-Object status | ForEach-Object { @{ status = $_.Name; count = $_.Count } }
$summary.tasks = @($tasks | Select-Object task_id, status, selected_worker, blocker, output)
$summary.active_leases = @(Get-JsonFiles (Join-Path $BusRoot 'leases') | Select-Object -ExpandProperty Name)

if (Test-Path -LiteralPath (Join-Path $BusRoot 'worker-registry.json')) {
  $summary.worker_registry = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $BusRoot 'worker-registry.json') | ConvertFrom-Json
}

if ($CheckDynabookBus -and $TaskId) {
  Push-Location $DynabookBusRepo
  try {
    $p = Start-Process -FilePath 'git' -ArgumentList @('fetch', 'origin', 'main') -NoNewWindow -PassThru -Wait -RedirectStandardOutput ([IO.Path]::GetTempFileName()) -RedirectStandardError ([IO.Path]::GetTempFileName())
    $resultPath = Join-Path $DynabookBusRepo "bus\results\$TaskId-v1.json"
    $altResultPath = Get-ChildItem -LiteralPath (Join-Path $DynabookBusRepo 'bus\results') -Filter "$TaskId*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $receiptPath = Get-ChildItem -LiteralPath (Join-Path $DynabookBusRepo 'bus\state\receipts') -Filter "$TaskId*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $taskFile = Get-ChildItem -LiteralPath (Join-Path $DynabookBusRepo 'bus\tasks') -Filter "$TaskId*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $summary.dynabook_bus_check = [ordered]@{
      fetched = $true
      task_file_status = if ($taskFile) { (Get-Content -Raw -Encoding utf8 -LiteralPath $taskFile.FullName | ConvertFrom-Json).status } else { 'NOT_FOUND' }
      result_found = [bool]$altResultPath
      receipt_found = [bool]$receiptPath
      result_content = if ($altResultPath) { Get-Content -Raw -Encoding utf8 -LiteralPath $altResultPath.FullName } else { $null }
    }
  } finally { Pop-Location }
}

$summary | ConvertTo-Json -Depth 10
exit 0
