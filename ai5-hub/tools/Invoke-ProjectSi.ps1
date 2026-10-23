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
Never                   : changes repo visibility, deletes repos/branches, force pushes, reads or prints tokens,
                          touches DAIMON / ROKU / AI5 HUB production files.
Exit codes              : 0 = ok; 3 = refused / failed (state in JSON).
#>
param(
  [Parameter(Mandatory = $true)][ValidateSet('preflight', 'create-repo', 'verify', 'test', 'run', 'jobs')][string]$Op,
  [ValidateSet('status', 'selftest', 'baseline-echo', 'baseline-local7b', 'memory-eval', 'guard',
    'bench-generate', 'bench-verify', 'runs-verify', 'heldout-echo', 'heldout-random', 'heldout-local7b', 'heldout-local7b-wait', 'state')][string]$Sub = 'status'
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
