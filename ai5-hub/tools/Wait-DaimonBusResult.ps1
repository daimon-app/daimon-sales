<#
DAIMON Tool Executor: BUS_RESULT_WAIT
Purpose                 : read-only wait for another device's Result on the GitHub Result Bus, replacing ad-hoc
                          "for ...; git fetch; git cat-file ..." loops (2026-10-20 audit).
Input schema            : -TaskId [A-Z0-9-]{8,120}   -MaxMinutes 1..30 (default 20)   -IntervalSeconds 15..120
Path/scope restriction  : ai5-github-result-bus only; git fetch (remote-tracking refs) + git show of
                          origin/main:bus/results/<TaskId>-v*.json and bus/tasks/<TaskId>.json. No writes.
Output                  : one line per status change, then the Result JSON (or WAIT_TIMEOUT).
Exit codes              : 0 = result found; 4 = timeout; 2 = invalid input.
#>
param(
  [Parameter(Mandatory = $true)][string]$TaskId,
  [ValidateRange(1, 30)][int]$MaxMinutes = 20,
  [ValidateRange(15, 120)][int]$IntervalSeconds = 30
)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($TaskId -notmatch '^[A-Z0-9][A-Z0-9-]{7,119}$') { 'INVALID_INPUT: TaskId'; exit 2 }
$Dir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'ai5-github-result-bus'
$deadline = (Get-Date).AddMinutes($MaxMinutes); $last = ''
while ($true) {
  & git -C $Dir fetch -q origin main 2>$null
  $hit = @(& git -C $Dir ls-tree --name-only origin/main bus/results/ 2>$null | Where-Object { $_ -match "^bus/results/$([regex]::Escape($TaskId))-v\d+\.json$" }) | Sort-Object | Select-Object -Last 1
  if ($hit) { "RESULT_FOUND $hit"; & git -C $Dir show "origin/main:$hit" 2>$null; exit 0 }
  $task = (& git -C $Dir show "origin/main:bus/tasks/$TaskId.json" 2>$null) -join "`n"
  $st = if ($task -match '"status"\s*:\s*"([A-Z_]+)"') { $Matches[1] } else { 'TASK_NOT_ON_REMOTE' }
  if ($st -ne $last) { "$((Get-Date).ToString('HH:mm:ss')) task_status=$st"; $last = $st }
  if ((Get-Date) -ge $deadline) { "WAIT_TIMEOUT task_status=$st"; exit 4 }
  Start-Sleep -Seconds $IntervalSeconds
}
