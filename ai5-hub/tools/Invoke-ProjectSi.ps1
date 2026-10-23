<#
DAIMON Tool Executor: PROJECT_SI
Purpose                 : fixed entry point for PROJECT SI research work, so no ad-hoc gh / git / python is needed.
Ops (fixed)             : preflight   - read-only: gh present/authenticated account, remote repo existence + visibility,
                                        local working copy state.
                          create-repo - Owner-approved 2026-10-23: create <account>/project-si as PRIVATE only (never
                                        public/internal), then init the local working copy <daimon-sales>\project-si
                                        with origin set. Existing repo: never recreated, never re-scoped.
                          verify      - read-only: remote visibility must be PRIVATE; remote head vs local head.
                          test        - python unittest discovery in project-si (stdlib only).
                          run         - python -m si <Sub> with a fixed subcommand set.
                          jobs        - read-only: running PROJECT SI / llama processes.
                          codex-activity - read-only: is Codex really working or only resident? Samples CPU time of
                                        codex processes and their descendants twice, lists child processes and the
                                        newest Codex session-log write time (file names/times only, never contents).
                                        Never stops anything.
                          dev-worktree - creates (once) the separate development working copy <daimon-sales>\project-si-dev
                                        on branch dev/si004-memory-reasoning-cli via "git worktree add"; the frozen
                                        measurement copy's files are not touched.
                          dev-test    - unittest in project-si-dev; refused while the 7B measurement is RUNNING.
                          dev-run     - python -m si <DevSub> in project-si-dev (light subcommands only); refused while
                                        the 7B measurement is RUNNING.
                          dev-verify  - read-only: remote private + dev branch head vs local dev head.
Never                   : changes repo visibility, deletes repos/branches, force pushes, reads or prints tokens,
                          touches DAIMON / ROKU / AI5 HUB production files.
Exit codes              : 0 = ok; 3 = refused / failed (state in JSON).
#>
param(
  [Parameter(Mandatory = $true)][ValidateSet('preflight', 'create-repo', 'verify', 'test', 'run', 'jobs',
    'codex-activity', 'dev-worktree', 'dev-test', 'dev-run', 'dev-verify')][string]$Op,
  [ValidateSet('status', 'selftest', 'baseline-echo', 'baseline-local7b', 'memory-eval', 'guard',
    'bench-generate', 'bench-verify', 'runs-verify', 'heldout-echo', 'heldout-random', 'heldout-local7b', 'heldout-local7b-wait', 'state')][string]$Sub = 'status',
  # Light (no 7B) subcommands only: the development copy never starts the measured model.
  [ValidateSet('status', 'selftest', 'memory-eval', 'memory2-eval', 'reason-eval', 'chat-demo', 'runs-verify')][string]$DevSub = 'status'
)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Dir = Join-Path $Root 'project-si'
$RepoName = 'project-si'
$report = [ordered]@{ schema_version = '1.0'; tool = 'PROJECT_SI'; op = $Op; state = 'STARTED'; secret_recorded = $false }
function Done([string]$state, [int]$code) { $report.state = $state; $report | ConvertTo-Json -Depth 6; exit $code }
function G { & git -C $Dir @args 2>&1 | ForEach-Object { "$_" } }
$Gh = (Get-Command gh -ErrorAction SilentlyContinue | Select-Object -First 1).Source
function GhAccount {
  if (-not $Gh) { return $null }
  $login = (& $Gh api user --jq .login 2>$null | Select-Object -First 1)
  if ($LASTEXITCODE -ne 0) { return $null }
  return "$login".Trim()
}
function GhRepo([string]$full) {
  $j = & $Gh repo view $full --json name,owner,visibility,isPrivate,url,defaultBranchRef 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $j) { return $null }
  return ($j -join "`n" | ConvertFrom-Json)
}
$PyExe = (Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
function Invoke-Py { & $PyExe @args 2>&1 | ForEach-Object { "$_" } }

if ($Op -eq 'jobs') {
  # Read-only: PROJECT SI's own python processes (python -m si ...) and any llama.cpp process, so a second
  # copy of a long job is never started by mistake. Nothing is stopped here.
  $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
      ($_.Name -match '^python' -and $_.CommandLine -match '-m si\b') -or $_.Name -match '^llama' })
  $report.processes = @($procs | ForEach-Object {
      [ordered]@{ pid = $_.ProcessId; parent_pid = $_.ParentProcessId; name = $_.Name
        started = "$($_.CreationDate)"; args = (($_.CommandLine -replace '^.*?-m si', 'python -m si') -replace '"', '') } })
  $report.count = $procs.Count
  Done 'OK' 0
}

if ($Op -eq 'codex-activity') {
  # Read-only. Answers "is Codex working right now, or only left resident?" without stopping or signalling it.
  $sampleSec = 20
  function Snap {
    $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    $byParent = @{}
    foreach ($p in $all) { $k = [int]$p.ParentProcessId; if (-not $byParent[$k]) { $byParent[$k] = @() }; $byParent[$k] += $p }
    $roots = @($all | Where-Object { $_.Name -match '^codex' })
    $tree = @{}
    $queue = New-Object System.Collections.Queue
    foreach ($r in $roots) { $queue.Enqueue($r) }
    while ($queue.Count) {
      $p = $queue.Dequeue()
      if ($tree.ContainsKey([int]$p.ProcessId)) { continue }
      $tree[[int]$p.ProcessId] = $p
      foreach ($c in @($byParent[[int]$p.ProcessId])) { if ($c) { $queue.Enqueue($c) } }
    }
    return @{ roots = $roots; tree = $tree; at = Get-Date }
  }
  function CpuSec($p) { ([double]$p.KernelModeTime + [double]$p.UserModeTime) / 1e7 }
  # Command lines may carry secrets: home path shortened, key/token-like values masked, length capped.
  function Hide([string]$s) {
    if (-not $s) { return $null }
    $s = $s.Replace($env:USERPROFILE, '~')
    $s = $s -replace '(?i)((?:token|key|secret|password|passwd|cookie|auth)[^=\s:]*[=:\s]+)\S+', '$1***'
    $s = $s -replace '[A-Za-z0-9+/=_-]{32,}', '***'
    if ($s.Length -gt 220) { $s = $s.Substring(0, 220) + '...' }
    return $s
  }
  $a = Snap
  Start-Sleep -Seconds $sampleSec
  $b = Snap
  $rows = foreach ($procId in $b.tree.Keys) {
    $p = $b.tree[$procId]
    $before = $a.tree[$procId]
    $delta = if ($before) { [math]::Round((CpuSec $p) - (CpuSec $before), 2) } else { $null }
    $created = try { [Management.ManagementDateTimeConverter]::ToDateTime("$($p.CreationDate)") } catch { $p.CreationDate }
    [ordered]@{
      pid = $procId; parent_pid = [int]$p.ParentProcessId; name = $p.Name
      exe = (Hide "$($p.ExecutablePath)"); command_line = (Hide "$($p.CommandLine)")
      is_codex = [bool]($p.Name -match '^codex'); new_during_sample = (-not $before)
      started = "$created"; age_minutes = $(if ($created -is [datetime]) { [math]::Round(((Get-Date) - $created).TotalMinutes, 1) } else { $null })
      working_set_mib = [math]::Round([double]$p.WorkingSetSize / 1MB, 1)
      cpu_seconds_total = [math]::Round((CpuSec $p), 1); cpu_seconds_in_sample = $delta
    }
  }
  $rows = @($rows | Sort-Object { $_.pid })
  $gone = @($a.tree.Keys | Where-Object { -not $b.tree.ContainsKey($_) })
  # Parent of each codex root: alive? (an orphaned codex whose launcher is gone is a typical leftover)
  $rootInfo = foreach ($r in $b.roots) {
    $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$r.ParentProcessId)" -ErrorAction SilentlyContinue
    [ordered]@{ pid = [int]$r.ProcessId; name = $r.Name; parent_pid = [int]$r.ParentProcessId; parent_alive = [bool]$parent
      parent_name = $(if ($parent) { $parent.Name } else { $null })
      parent_exe = $(if ($parent) { Hide "$($parent.ExecutablePath)" } else { $null }) }
  }
  # Newest Codex session log write (names and times only).
  $sessDir = Join-Path $env:USERPROFILE '.codex\sessions'
  $newest = $null
  if (Test-Path -LiteralPath $sessDir) {
    $newest = Get-ChildItem -LiteralPath $sessDir -Recurse -File -Filter '*.jsonl' -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending | Select-Object -First 3
  }
  $cpuTotal = [math]::Round((@($rows | ForEach-Object { if ($_.cpu_seconds_in_sample) { $_.cpu_seconds_in_sample } else { 0 } }) | Measure-Object -Sum).Sum, 2)
  $report.sample_seconds = $sampleSec
  $report.codex_root_count = @($b.roots).Count
  $report.codex_roots = @($rootInfo)
  $report.tree_process_count = $rows.Count
  $report.cpu_seconds_used_in_sample = $cpuTotal
  $report.cpu_share_of_one_core = $(if ($sampleSec) { [math]::Round($cpuTotal / $sampleSec, 3) } else { $null })
  $report.processes_started_in_sample = @($rows | Where-Object { $_.new_during_sample }).Count
  $report.processes_ended_in_sample = $gone.Count
  $report.processes = $rows
  $report.newest_session_logs = @($newest | ForEach-Object {
      [ordered]@{ file = $_.Name; last_write = $_.LastWriteTime.ToString('s'); minutes_ago = [math]::Round(((Get-Date) - $_.LastWriteTime).TotalMinutes, 1) } })
  $active = ($cpuTotal -ge 1.0) -or ($report.processes_started_in_sample -gt 0) -or ($newest -and ((Get-Date) - $newest[0].LastWriteTime).TotalMinutes -lt 10)
  $report.verdict = $(if (-not @($b.roots).Count) { 'NO_CODEX' } elseif ($active) { 'CODEX_ACTIVE' } else { 'CODEX_RESIDENT_IDLE' })
  Done 'OK' 0
}

$DevDir = Join-Path $Root 'project-si-dev'
$DevBranch = 'dev/si004-memory-reasoning-cli'
function MeasurementRunning {
  $sf = Join-Path $Dir 'evidence\state\heldout-local7b.json'
  if (-not (Test-Path -LiteralPath $sf)) { return $false }
  try { return ((Get-Content -LiteralPath $sf -Raw -Encoding UTF8 | ConvertFrom-Json).phase -eq 'RUNNING') } catch { return $false }
}

if ($Op -eq 'dev-worktree') {
  $report.dev_dir = $DevDir; $report.dev_branch = $DevBranch
  if (Test-Path -LiteralPath (Join-Path $DevDir '.git')) {
    $report.created = $false
    $report.dev_head = (& git -C $DevDir log -1 --format='%h %s' 2>$null | Select-Object -First 1)
    $report.dev_current_branch = (& git -C $DevDir symbolic-ref --short -q HEAD 2>$null | Select-Object -First 1)
    Done 'DEV_WORKTREE_READY' 0
  }
  if (Test-Path -LiteralPath $DevDir) { Done 'REFUSED_DEV_DIR_EXISTS_NOT_A_WORKTREE' 3 }
  $exists = [bool](G rev-parse --verify -q "refs/heads/$DevBranch" | Select-Object -First 1)
  $out = if ($exists) { G worktree add $DevDir $DevBranch } else { G worktree add -b $DevBranch $DevDir HEAD }
  $report.git = @($out | Select-Object -First 5)
  if (-not (Test-Path -LiteralPath (Join-Path $DevDir '.git'))) { Done 'DEV_WORKTREE_FAILED' 3 }
  $report.created = $true
  $report.dev_head = (& git -C $DevDir log -1 --format='%h %s' 2>$null | Select-Object -First 1)
  Done 'DEV_WORKTREE_READY' 0
}

if ($Op -eq 'dev-verify') {
  if (-not $Gh) { Done 'GH_CLI_MISSING' 3 }
  $acct = GhAccount
  if (-not $acct) { Done 'GH_NOT_AUTHENTICATED' 3 }
  $repo = GhRepo "$acct/$RepoName"
  if (-not $repo) { Done 'REMOTE_MISSING' 3 }
  $report.is_private = [bool]$repo.isPrivate; $report.visibility = $repo.visibility
  if (-not $repo.isPrivate) { Done 'FAIL_REPO_NOT_PRIVATE' 3 }
  if (-not (Test-Path -LiteralPath (Join-Path $DevDir '.git'))) { Done 'DEV_WORKTREE_MISSING' 3 }
  & git -C $DevDir fetch -q origin $DevBranch 2>$null | Out-Null
  $report.dev_branch = $DevBranch
  $report.remote_head = (& git -C $DevDir rev-parse --short "origin/$DevBranch" 2>$null | Select-Object -First 1)
  $report.local_head_short = (& git -C $DevDir rev-parse --short HEAD 2>$null | Select-Object -First 1)
  $report.in_sync = ($report.remote_head -and $report.remote_head -eq $report.local_head_short)
  Done ($(if ($report.in_sync) { 'VERIFIED_PRIVATE_DEV_IN_SYNC' } else { 'VERIFIED_PRIVATE_DEV_NOT_IN_SYNC' })) 0
}

if ($Op -in @('dev-test', 'dev-run')) {
  # The 7B measurement has priority: no development load while it is running.
  if (MeasurementRunning) { Done 'DEFERRED_7B_MEASUREMENT_RUNNING' 0 }
  if (-not (Test-Path -LiteralPath (Join-Path $DevDir 'src\si'))) { Done 'DEV_WORKTREE_MISSING' 3 }
  Push-Location $DevDir
  try {
    $env:PYTHONPATH = Join-Path $DevDir 'src'
    $env:PYTHONDONTWRITEBYTECODE = '1'
    if ($Op -eq 'dev-test') {
      $out = Invoke-Py -m unittest discover -s tests -t . -v
      $code = $LASTEXITCODE
      $report.output_tail = @($out | Select-Object -Last 40)
      Done ($(if ($code -eq 0) { 'DEV_TESTS_PASSED' } else { 'DEV_TESTS_FAILED' })) ($(if ($code -eq 0) { 0 } else { 3 }))
    }
    $out = Invoke-Py -m si $DevSub
    $code = $LASTEXITCODE
    $report.sub = $DevSub
    $report.output_tail = @($out | Select-Object -Last 80)
    Done ($(if ($code -eq 0) { 'DEV_RUN_OK' } else { 'DEV_RUN_FAILED' })) ($(if ($code -eq 0) { 0 } else { 3 }))
  } finally { Pop-Location }
}

if ($Op -in @('preflight', 'create-repo', 'verify')) {
  $report.gh_present = [bool]$Gh
  if (-not $Gh) { Done 'GH_CLI_MISSING' 3 }
  $acct = GhAccount
  $report.gh_account = $acct
  if (-not $acct) { Done 'GH_NOT_AUTHENTICATED' 3 }
  $full = "$acct/$RepoName"
  $repo = GhRepo $full
  $report.repo = $full
  $report.remote_exists = [bool]$repo
  if ($repo) { $report.visibility = $repo.visibility; $report.is_private = [bool]$repo.isPrivate; $report.url = $repo.url }
  $report.local_exists = Test-Path -LiteralPath (Join-Path $Dir '.git')
  if ($report.local_exists) {
    $report.local_branch = (G rev-parse --abbrev-ref HEAD | Select-Object -First 1)
    $report.local_head = (G log -1 --format='%h %s' 2>$null | Select-Object -First 1)
    $report.origin = (G remote get-url origin | Select-Object -First 1)
  }
  if ($Op -eq 'preflight') { Done 'OK' 0 }

  if ($Op -eq 'create-repo') {
    if (-not $repo) {
      $out = & $Gh repo create $RepoName --private --disable-wiki --description 'PROJECT SI - independent intelligence research (private)' 2>&1
      $report.create_output = @($out | ForEach-Object { "$_" } | Select-Object -First 3)
      if ($LASTEXITCODE -ne 0) { Done 'CREATE_FAILED' 3 }
      $repo = GhRepo $full
      $report.created = $true
    } else { $report.created = $false }
    if (-not $repo) { Done 'CREATE_NOT_VISIBLE' 3 }
    $report.visibility = $repo.visibility; $report.is_private = [bool]$repo.isPrivate; $report.url = $repo.url
    if (-not $repo.isPrivate) { Done 'REFUSED_REPO_NOT_PRIVATE' 3 }  # never continue on a non-private repo
    if (-not (Test-Path -LiteralPath (Join-Path $Dir '.git'))) {
      New-Item -ItemType Directory -Force -Path $Dir | Out-Null
      G init -q -b main | Out-Null
      G remote add origin "$($repo.url).git" | Out-Null
      $report.local_initialized = $true
    }
    $report.origin = (G remote get-url origin | Select-Object -First 1)
    # Same commit identity as the DAIMON repository (repo-local config only; global config untouched).
    foreach ($k in 'user.name', 'user.email') {
      if (-not (G config --local --get $k | Select-Object -First 1)) {
        $v = (& git -C $Root config --get $k 2>$null | Select-Object -First 1)
        if ($v) { G config --local $k "$v" | Out-Null }
      }
    }
    $report.identity_set = [bool](G config --local --get user.name | Select-Object -First 1)
    Done 'REPO_READY_PRIVATE' 0
  }

  # verify
  if (-not $repo) { Done 'REMOTE_MISSING' 3 }
  if (-not $repo.isPrivate) { Done 'FAIL_REPO_NOT_PRIVATE' 3 }
  G fetch -q origin | Out-Null
  $report.remote_head = (G rev-parse --short origin/main 2>$null | Select-Object -First 1)
  $report.local_head_short = (G rev-parse --short HEAD 2>$null | Select-Object -First 1)
  $report.in_sync = ($report.remote_head -and $report.remote_head -eq $report.local_head_short)
  Done ($(if ($report.in_sync) { 'VERIFIED_PRIVATE_IN_SYNC' } else { 'VERIFIED_PRIVATE_NOT_IN_SYNC' })) 0
}

if (-not (Test-Path -LiteralPath (Join-Path $Dir 'src\si'))) { Done 'PROJECT_SI_SOURCE_MISSING' 3 }
Push-Location $Dir
try {
  $env:PYTHONPATH = Join-Path $Dir 'src'
  $env:PYTHONDONTWRITEBYTECODE = '1'
  if ($Op -eq 'test') {
    $out = Invoke-Py -m unittest discover -s tests -t . -v
    $code = $LASTEXITCODE
    $report.output_tail = @($out | Select-Object -Last 40)
    Done ($(if ($code -eq 0) { 'TESTS_PASSED' } else { 'TESTS_FAILED' })) ($(if ($code -eq 0) { 0 } else { 3 }))
  }
  $out = Invoke-Py -m si $Sub
  $code = $LASTEXITCODE
  $report.sub = $Sub
  $report.output_tail = @($out | Select-Object -Last 60)
  Done ($(if ($code -eq 0) { 'RUN_OK' } elseif ($code -eq 2) { 'RUN_BLOCKED_BY_GUARD' } else { 'RUN_FAILED' })) ($(if ($code -in 0, 2) { 0 } else { 3 }))
} finally { Pop-Location }
