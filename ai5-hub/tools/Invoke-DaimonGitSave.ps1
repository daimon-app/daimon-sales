<#
DAIMON Tool Executor: SAFE_GIT_STAGE_EXPLICIT + SAFE_GIT_COMMIT_DAIMON + SAFE_GIT_PUSH_APPROVED_BRANCH
Purpose                 : save (commit) and send (push) an explicit list of DAIMON files without ad-hoc Git.
Input schema            : -Repo daimon-sales|result-bus  -Paths <repo-relative files, explicit list>
                          -Message <commit subject/body, 1..2000 chars>  [-Push]
Checks (all fail-closed): repository root fixed; current branch must be an approved branch of that repo;
                          nothing else may already be staged; no merge/rebase in progress; every path is
                          repo-relative, exists, has no '..' / wildcard / option prefix, lies under an approved
                          prefix and does not look like a secret file; staged added lines are scanned for
                          private keys / tokens / password literals (hit = unstage and refuse).
Push                    : fetch; if the remote moved, merge (no rebase) only when the incoming files do not
                          overlap the files of this commit, else stop; plain "git push origin HEAD:<branch>",
                          up to 3 attempts. Never --force, never another branch.
Never                   : reset --hard, clean, checkout/switch, rebase, stash, branch delete, tag, force push,
                          staging of files that were not named, deletion of files.
Exit codes              : 0 = SAVED / PUSHED / NOTHING_TO_COMMIT; 3 = refused (state in JSON).
#>
param(
  [Parameter(Mandatory = $true)][ValidateSet('daimon-sales', 'result-bus', 'project-si', 'project-si-dev')][string]$Repo,
  [Parameter(Mandatory = $true)][string[]]$Paths,
  [Parameter(Mandatory = $true)][ValidateLength(1, 2000)][string]$Message,
  [switch]$Push
)
$ErrorActionPreference = 'Continue'  # PS 5.1: 'Stop' turns git's stderr progress lines into terminating errors
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Policy = @{
  'daimon-sales' = @{ dir = $Root; branch = '^(feat/ai5-sales-factory-v6|claude-fallback/[A-Za-z0-9._-]+)$'
    prefixes = @('ai5-hub/', 'claude-fallback/', '.claude/settings.json') }
  'result-bus'   = @{ dir = (Join-Path $Root 'ai5-github-result-bus'); branch = '^main$'
    prefixes = @('bus/', 'worker/', 'config/', 'docs/') }
  # PROJECT SI private research repository (Owner-approved 2026-10-23); nested working copy like the Result Bus.
  'project-si'   = @{ dir = (Join-Path $Root 'project-si'); branch = '^main$'
    prefixes = @('README.md', 'MASTER.md', 'AGENTS.md', '.gitignore', '.gitattributes', 'pyproject.toml', 'docs/', 'src/', 'experiments/',
      'benchmarks/', 'tests/', 'configs/', 'scripts/', 'reports/', 'evidence/') }
  # PROJECT SI development worktree (separate folder, dev/* branches only) so the measured copy stays frozen.
  'project-si-dev' = @{ dir = (Join-Path $Root 'project-si-dev'); branch = '^dev/[A-Za-z0-9._-]+$'
    prefixes = @('README.md', 'MASTER.md', 'AGENTS.md', '.gitignore', '.gitattributes', 'pyproject.toml', 'docs/', 'src/', 'experiments/',
      'benchmarks/', 'tests/', 'configs/', 'scripts/', 'reports/', 'evidence/') }
}[$Repo]
$Dir = $Policy.dir
$Trailer = 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
$report = [ordered]@{ schema_version = '1.0'; tool = 'SAFE_GIT_SAVE'; repo = $Repo; state = 'STARTED'; files = @(); secret_recorded = $false }
function G { & git -C $Dir @args 2>&1 | ForEach-Object { "$_" } }
function Done([string]$state, [int]$code) { $report.state = $state; $report | ConvertTo-Json -Depth 4; exit $code }

# Paths may arrive as one comma/space separated string from the shell.
$list = @($Paths | ForEach-Object { $_ -split '[,\s]+' } | Where-Object { $_ } | ForEach-Object { $_.Replace('\', '/') } | Select-Object -Unique)
# symbolic-ref also works before the first commit (rev-parse --abbrev-ref answers "HEAD" there).
$branch = (G symbolic-ref --short -q HEAD | Select-Object -First 1)
$report.branch = $branch
if ($branch -notmatch $Policy.branch) { Done 'REFUSED_BRANCH_NOT_APPROVED' 3 }
$gitDir = (G rev-parse --absolute-git-dir | Select-Object -First 1)
foreach ($m in 'MERGE_HEAD', 'REBASE_HEAD', 'rebase-merge', 'rebase-apply', 'CHERRY_PICK_HEAD') {
  if (Test-Path -LiteralPath (Join-Path $gitDir $m)) { Done "REFUSED_OPERATION_IN_PROGRESS:$m" 3 }
}
foreach ($p in $list) {
  $ok = $p -match '^[A-Za-z0-9._][A-Za-z0-9._/ -]{0,200}$' -and $p -notmatch '\.\.' -and -not $p.StartsWith('-')
  $ok = $ok -and @($Policy.prefixes | Where-Object { $p -eq $_ -or ($_.EndsWith('/') -and $p.StartsWith($_)) }).Count -gt 0
  $ok = $ok -and ((Split-Path -Leaf $p) -notmatch '(?i)(^\.env|\.pem$|\.key$|\.pfx$|\.p12$|id_rsa|id_ed25519|credential|password|cookie|token)')
  if (-not $ok) { $report.rejected_path = $p; Done 'REFUSED_PATH_NOT_ALLOWED' 3 }
  if (-not (Test-Path -LiteralPath (Join-Path $Dir $p) -PathType Leaf)) { $report.rejected_path = $p; Done 'REFUSED_PATH_MISSING_OR_NOT_FILE' 3 }
}
# Already-staged files are accepted only when they are among the named files (e.g. left by a failed commit).
$preStaged = @(G diff --cached --name-only | Where-Object { $_ })
$foreign = @($preStaged | Where-Object { $list -notcontains $_ })
if ($foreign.Count) { $report.foreign_staged = $foreign; Done 'REFUSED_FOREIGN_STAGED_CHANGES' 3 }
G add -- @list | Out-Null
$staged = @(G diff --cached --name-only | Where-Object { $_ })
$report.files = $staged
$extra = @($staged | Where-Object { $list -notcontains $_ })
if ($extra.Count) { G restore --staged -- @staged | Out-Null; $report.unexpected = $extra; Done 'REFUSED_UNEXPECTED_STAGED_FILE' 3 }
if (-not $staged.Count) { Done 'NOTHING_TO_COMMIT' 0 }
$added = (G diff --cached -U0 | Where-Object { $_ -like '+*' -and $_ -notlike '+++*' }) -join "`n"
$secretRe = 'BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|(?i)"?(password|passwd|api[_-]?key|client[_-]?secret|access[_-]?token)"?\s*[:=]\s*"[^"\s]{6,}"'
if ($added -match $secretRe) { G restore --staged -- @staged | Out-Null; Done 'REFUSED_SECRET_PATTERN_IN_DIFF' 3 }
$msgFile = Join-Path $env:TEMP ("daimon-commit-" + [guid]::NewGuid().ToString('N') + '.txt')
$body = $Message.Trim()
if ($body -notmatch [regex]::Escape($Trailer)) { $body += "`n`n$Trailer" }
[System.IO.File]::WriteAllText($msgFile, $body + "`n", (New-Object System.Text.UTF8Encoding($false)))
$out = G commit -q -F $msgFile
Remove-Item -LiteralPath $msgFile -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) { $report.git = $out; Done 'COMMIT_FAILED' 3 }
$report.commit = (G log -1 --format='%h %s' | Select-Object -First 1)
if (-not $Push) { Done 'SAVED' 0 }

for ($attempt = 1; $attempt -le 3; $attempt++) {
  G fetch -q origin $branch | Out-Null
  # An empty new remote has no origin/<branch> yet: nothing to merge.
  $hasRemote = [bool](G rev-parse --verify -q "refs/remotes/origin/$branch" | Select-Object -First 1)
  $behind = if ($hasRemote) { [int](G rev-list --count "HEAD..origin/$branch" | Select-Object -First 1) } else { 0 }
  if ($behind -gt 0) {
    $incoming = @(G diff --name-only "HEAD...origin/$branch" | Where-Object { $_ })
    $overlap = @($incoming | Where-Object { $staged -contains $_ })
    if ($overlap.Count) { $report.overlap = $overlap; Done 'SAVED_PUSH_STOPPED_REMOTE_TOUCHED_SAME_FILES' 3 }
    $m = G merge --no-edit -q "origin/$branch"
    if ($LASTEXITCODE -ne 0) { G merge --abort | Out-Null; $report.git = $m; Done 'SAVED_PUSH_STOPPED_MERGE_CONFLICT' 3 }
    $report.merged_remote_commits = $behind
  }
  $p = G push -q origin "HEAD:$branch"
  if ($LASTEXITCODE -eq 0) { $report.pushed_head = (G log -1 --format='%h' | Select-Object -First 1); $report.push_attempts = $attempt; Done 'PUSHED' 0 }
  $report.git = $p
}
Done 'SAVED_PUSH_FAILED' 3
