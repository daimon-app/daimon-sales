<#
DAIMON Tool Executor: SESSION_RESTORE
Exact allowed operation : print ai5-hub/CLAUDE_SESSION_RESTORE.md plus a dynamic OWNER_GATE_STATE /
                          latest-checkpoint summary computed from the local Result Bus clone.
                          Invoked by the Claude Code SessionStart hook (startup/resume/clear/compact),
                          whose stdout is injected into the new session's context.
Input schema            : none except -RepoRoot.
Path/scope restriction  : read-only. Reads only <repo>\ai5-hub\CLAUDE_SESSION_RESTORE.md and
                          <repo>\ai5-github-result-bus\bus\{tasks,results}\*.json. Writes nothing.
Timeout                 : n/a (local file reads only).
Exit codes              : 0 always - a restore failure must never block session start; errors are
                          reported in the output as RESTORE_WARNING.
Result/Receipt/Evidence : stdout only.
#>
param(
  [string]$RepoRoot = 'C:\Users\teppe\Documents\GitHub\daimon-sales'
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
$OutputEncoding = [Text.UTF8Encoding]::new($false)
$utf8 = [Text.UTF8Encoding]::new($false)

try {
  [IO.File]::ReadAllText((Join-Path $RepoRoot 'ai5-hub\CLAUDE_SESSION_RESTORE.md'), $utf8) | Write-Output
} catch {
  Write-Output "RESTORE_WARNING: CLAUDE_SESSION_RESTORE.md unreadable ($($_.Exception.Message)). JAPANESE_MODE=ON remains mandatory."
}

$lines = [Collections.Generic.List[string]]::new()
$lines.Add('### DYNAMIC_STATE (computed by SessionStart hook)')
$lines.Add("- restored_at: $([DateTimeOffset]::Now.ToString('o'))")
try {
  $busRoot = Join-Path $RepoRoot 'ai5-github-result-bus\bus'
  $waiting = [Collections.Generic.List[string]]::new()
  $runnable = [Collections.Generic.List[string]]::new()
  $staleCount = 0
  foreach ($file in Get-ChildItem -LiteralPath (Join-Path $busRoot 'tasks') -Filter *.json -File) {
    try { $task = [IO.File]::ReadAllText($file.FullName, $utf8) | ConvertFrom-Json } catch { continue }
    if ([string]::IsNullOrWhiteSpace([string]$task.task_id)) { continue }  # plan/report files, not tasks
    switch ([string]$task.status) {
      'WAITING_OWNER_GATE' { $waiting.Add("$($task.task_id) (gate=$($task.owner_gate_id), auto_resume=$($task.auto_resume_after_owner_gate))") }
      { $_ -in @('QUEUED','READY','RUNNING','CLAIMED') } {
        $stamp = if ($task.updated_at) { $task.updated_at } else { $task.created_at }
        $stale = $false
        try { $stale = ([DateTimeOffset]::Now - [DateTimeOffset]::Parse([string]$stamp)).TotalDays -gt 14 } catch {}
        if ($stale) { $staleCount++ }
        else { $runnable.Add("$($task.task_id) [$($task.status)] ai=$($task.assigned_ai) target=$($task.target_device_id)") }
      }
    }
  }
  $gateState = if ($waiting.Count -eq 0) { 'NONE_WAITING' } else { 'WAITING' }
  $lines.Add("- OWNER_GATE_STATE: $gateState ($($waiting.Count) task)")
  foreach ($w in $waiting) { $lines.Add("  - $w") }
  $lines.Add("- RUNNABLE_TASKS (updated within 14 days): $($runnable.Count)")
  $lines.Add("- STALE_QUEUED_TASKS (older than 14 days, legacy queue owned by their assigned_ai/device; NOT runnable by Claude fallback without ownership check): $staleCount")
  foreach ($r in $runnable | Select-Object -First 10) { $lines.Add("  - $r") }
  $latest = Get-ChildItem -LiteralPath (Join-Path $busRoot 'results') -Filter *.json -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 3
  $lines.Add('- LATEST_RESULTS (LAST_VERIFIED_CHECKPOINT candidates):')
  foreach ($f in $latest) {
    try {
      $result = [IO.File]::ReadAllText($f.FullName, $utf8) | ConvertFrom-Json
      $lines.Add("  - $($f.Name): status=$($result.status) result=$($result.result) finished_at=$($result.finished_at)")
    } catch { $lines.Add("  - $($f.Name): (parse failed)") }
  }
} catch {
  $lines.Add("- RESTORE_WARNING: Result Bus unreadable ($($_.Exception.Message)). Inspect Git and evidence directly.")
}
$lines -join "`n" | Write-Output
exit 0
