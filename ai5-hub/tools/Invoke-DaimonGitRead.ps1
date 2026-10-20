<#
DAIMON Tool Executor: SAFE_GIT_READ
Purpose                 : read-only Git views of the two DAIMON repositories, so Claude never builds ad-hoc
                          "git -C ... && ... | head" chains (2026-10-20 audit: 8 of 15 approval prompts).
Input schema            : -Repo daimon-sales|result-bus
                          -Op   status|log|diff-stat|diff-names|diff|fetch|incoming|show|exists
                          -Ref  (log/show/exists/incoming base; default HEAD / origin/<branch>)
                          -Path (diff/show/exists; repo-relative, validated)   -Count 1..50 (log, default 10)
Path/scope restriction  : fixed repository roots; refs and paths validated by regex; no '..', no options
                          injection. fetch only updates remote-tracking refs (never touches the work tree).
Never                   : checkout, reset, clean, merge, push, branch changes, config changes.
Exit codes              : 0 = output printed; 2 = invalid input.
#>
param(
  [Parameter(Mandatory = $true)][ValidateSet('daimon-sales', 'result-bus')][string]$Repo,
  [Parameter(Mandatory = $true)][ValidateSet('status', 'log', 'diff-stat', 'diff-names', 'diff', 'fetch', 'incoming', 'show', 'exists')][string]$Op,
  [string]$Ref,
  [string]$Path,
  [ValidateRange(1, 50)][int]$Count = 10
)
$ErrorActionPreference = 'Continue'  # PS 5.1: 'Stop' turns git's stderr progress lines into terminating errors
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Dir = if ($Repo -eq 'daimon-sales') { $Root } else { Join-Path $Root 'ai5-github-result-bus' }
function Fail([string]$m) { Write-Output "INVALID_INPUT: $m"; exit 2 }
if ($Ref -and ($Ref -notmatch '^[A-Za-z0-9][A-Za-z0-9._/~^-]{0,120}$' -or $Ref -match '\.\.')) { Fail 'ref' }
if ($Path -and ($Path -notmatch '^[A-Za-z0-9._][A-Za-z0-9._/ -]{0,200}$' -or $Path -match '\.\.' -or $Path.StartsWith('-'))) { Fail 'path' }
function G { & git -C $Dir @args 2>&1 | ForEach-Object { "$_" } }
$branch = (G rev-parse --abbrev-ref HEAD | Select-Object -First 1)
$upstream = "origin/$branch"
switch ($Op) {
  'status' { "repo=$Repo branch=$branch"; G status --short --branch }
  'log' { G log -n $Count --format='%h %ci %s' $(if ($Ref) { $Ref } else { 'HEAD' }) }
  'diff-stat' { if ($Path) { G diff --stat -- $Path } else { G diff --stat } }
  'diff-names' { G diff --name-status }
  'diff' { if (-not $Path) { Fail 'diff needs -Path' }; G diff -- $Path }
  'fetch' { G fetch -q origin; "fetched; $(G rev-list --left-right --count "HEAD...$upstream") (ahead behind)" }
  'incoming' {
    G fetch -q origin
    $base = if ($Ref) { $Ref } else { $upstream }
    "ahead_behind=$(G rev-list --left-right --count "HEAD...$base")"
    'incoming_commits:'; G log --format='%h %ci %s' "HEAD..$base"
    'incoming_files:'; G diff --name-only "HEAD...$base"
  }
  'show' {
    if (-not $Path) { G show --stat --format='%h %ci %an %s' $(if ($Ref) { $Ref } else { 'HEAD' }) }
    else { G show "$(if ($Ref) { $Ref } else { 'HEAD' }):$Path" }
  }
  'exists' {
    if (-not $Path) { Fail 'exists needs -Path' }
    $r = if ($Ref) { $Ref } else { 'HEAD' }
    & git -C $Dir cat-file -e "${r}:$Path" 2>$null
    if ($LASTEXITCODE -eq 0) { "EXISTS $r`:$Path" } else { "MISSING $r`:$Path" }
  }
}
exit 0
