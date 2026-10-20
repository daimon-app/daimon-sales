<#
DAIMON Tool Executor: PERMISSION_AUDIT
Purpose                 : read-only audit of Claude Code session transcripts for this project. Lists every Bash
                          command Claude ran, checks each sub-command against the CURRENT .claude/settings.json
                          allow / deny rules, and classifies the ones that would need an Owner approval prompt.
Categories              : A SAFE_READ_ONLY, B SAFE_FIXED_TOOL, C SAFE_REPO_WRITE, D TRUE_OWNER_GATE,
                          E DANGEROUS_DESTRUCTIVE, F AD_HOC_UNNEEDED.
Input schema            : -Since (date, default today 00:00 local), -Transcript (optional single .jsonl).
Path/scope restriction  : reads ~/.claude/projects/C--Users-teppe-Documents-GitHub-daimon-sales/*.jsonl and the
                          repo settings file only; writes nothing except stdout. Command texts are truncated to
                          160 chars; nothing secret is printed (transcripts never contain passwords by policy).
Exit codes              : 0 = report printed.
#>
param(
  [datetime]$Since = (Get-Date).Date,
  [string]$Transcript
)
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$SettingsPath = Join-Path $RepoRoot '.claude\settings.json'
$ProjectDir = Join-Path $env:USERPROFILE '.claude\projects\C--Users-teppe-Documents-GitHub-daimon-sales'

$settings = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
function Get-Rules([object[]]$list) {
  @($list | Where-Object { $_ -like 'Bash(*)' } | ForEach-Object { $_.Substring(5, $_.Length - 6) })
}
$allow = Get-Rules $settings.permissions.allow
$deny = if ($settings.permissions.PSObject.Properties.Name -contains 'deny') { Get-Rules $settings.permissions.deny } else { @() }

function Test-Rule([string]$cmd, [string[]]$rules) {
  foreach ($r in $rules) {
    if ($r.EndsWith('*')) { if ($cmd.StartsWith($r.Substring(0, $r.Length - 1))) { return $true } }
    elseif ($cmd -eq $r) { return $true }
  }
  return $false
}
function Split-Compound([string]$cmd) {
  # Split on && || ; | and newlines outside quotes (approximation of Claude Code's own splitting).
  $parts = @(); $cur = ''; $q = [char]0
  for ($i = 0; $i -lt $cmd.Length; $i++) {
    $c = $cmd[$i]
    if ($q -ne [char]0) { if ($c -eq $q) { $q = [char]0 }; $cur += $c; continue }
    if ($c -eq '"' -or $c -eq "'") { $q = $c; $cur += $c; continue }
    if ($c -eq "`n" -or $c -eq ';' -or $c -eq '|' -or ($c -eq '&' -and $i + 1 -lt $cmd.Length -and $cmd[$i + 1] -eq '&')) {
      if ($cur.Trim()) { $parts += $cur.Trim() }
      $cur = ''
      if (($c -eq '|' -or $c -eq '&') -and $i + 1 -lt $cmd.Length -and $cmd[$i + 1] -eq $c) { $i++ }
      continue
    }
    $cur += $c
  }
  if ($cur.Trim()) { $parts += $cur.Trim() }
  return $parts
}
function Get-Category([string]$cmd) {
  if ($cmd -match 'push\s+.*(--force|-f\b)|reset\s+--hard|git\s+(-C\s+\S+\s+)?clean|rebase|branch\s+-D|rm\s+-rf|Remove-Item|--dangerously') { return 'E' }
  if ($cmd -match '(?i)password|passwd|secret|token|mfa|otp') { return 'D' }
  if ($cmd -match '^git\s+(-C\s+\S+\s+)?(add|commit|push|merge|checkout|switch|stash|tag)\b') { return 'C' }
  if ($cmd -match '^git\s+(-C\s+\S+\s+)?(status|log|diff|show|fetch|rev-parse|branch|remote|cat-file|ls-files|worktree)\b') { return 'A' }
  if ($cmd -match '^powershell(\.exe)?\s+-NoProfile\s+-ExecutionPolicy\s+Bypass\s+-File\s+"[^"]+\\(ai5-hub\\tools|ai5-github-result-bus\\worker)\\') { return 'B' }
  return 'F'
}

$files = if ($Transcript) { @(Get-Item -LiteralPath $Transcript) } else { @(Get-ChildItem -LiteralPath $ProjectDir -Filter *.jsonl) }
$rows = @()
foreach ($f in $files) {
  foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
    if ($line -notmatch '"name":"Bash"') { continue }
    try { $o = $line | ConvertFrom-Json } catch { continue }
    $ts = $null; try { $ts = [datetime]$o.timestamp } catch { }
    if ($ts -and $ts -lt $Since) { continue }
    foreach ($c in @($o.message.content)) {
      if ($c.type -ne 'tool_use' -or $c.name -ne 'Bash') { continue }
      $cmd = [string]$c.input.command
      $subs = @(Split-Compound $cmd)
      $unlisted = @($subs | Where-Object { -not (Test-Rule $_ $allow) })
      $denied = @($subs | Where-Object { Test-Rule $_ $deny })
      $state = if ($denied.Count) { 'AUTO_DENIED' } elseif ($unlisted.Count) { 'OWNER_PROMPT' } else { 'AUTO_ALLOWED' }
      # Most severe category of the unlisted parts wins.
      $rank = 'E', 'D', 'C', 'F', 'A', 'B'
      $cat = if ($unlisted.Count) { ($unlisted | ForEach-Object { Get-Category $_ } | Sort-Object { $rank.IndexOf($_) } | Select-Object -First 1) } else { Get-Category $subs[0] }
      $rows += [pscustomobject]@{ session = $f.BaseName.Substring(0, 8); at = $ts; state = $state; category = $cat
        compound = ($subs.Count -gt 1); command = ($cmd -replace '\s+', ' ').Substring(0, [Math]::Min(160, ($cmd -replace '\s+', ' ').Length)) }
    }
  }
}
$prompts = @($rows | Where-Object { $_.state -eq 'OWNER_PROMPT' })
[ordered]@{
  schema_version = '1.0'; tool = 'PERMISSION_AUDIT'; generated_at = [DateTimeOffset]::Now.ToString('o'); since = $Since.ToString('s')
  bash_calls = $rows.Count
  auto_allowed = @($rows | Where-Object { $_.state -eq 'AUTO_ALLOWED' }).Count
  auto_denied = @($rows | Where-Object { $_.state -eq 'AUTO_DENIED' }).Count
  owner_prompts_under_current_rules = $prompts.Count
  prompts_by_category = [ordered]@{ A = @($prompts | ? category -eq 'A').Count; B = @($prompts | ? category -eq 'B').Count
    C = @($prompts | ? category -eq 'C').Count; D = @($prompts | ? category -eq 'D').Count
    E = @($prompts | ? category -eq 'E').Count; F = @($prompts | ? category -eq 'F').Count }
  compound_prompts = @($prompts | ? compound).Count
  prompts = @($prompts | ForEach-Object { "$($_.session) $(if ($_.at) { $_.at.ToString('MM-dd HH:mm') }) [$($_.category)] $($_.command)" })
  secret_recorded = $false
} | ConvertTo-Json -Depth 4
