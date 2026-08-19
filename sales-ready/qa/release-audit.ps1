$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$passes = New-Object System.Collections.Generic.List[string]

function Pass([string]$m) { $passes.Add($m) }
function Fail([string]$m) { $failures.Add($m) }
function Warn([string]$m) { $warnings.Add($m) }
function ReadUtf8([string]$p) {
  if (-not (Test-Path $p)) { return $null }
  return [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
}

$indexPath = Join-Path $root 'index.html'
$manifestPath = Join-Path $root 'manifest.json'
$swPath = Join-Path $root 'sw.js'

$index = ReadUtf8 $indexPath
$manifestRaw = ReadUtf8 $manifestPath
$sw = ReadUtf8 $swPath

if ($null -eq $index) { Fail 'index.html missing' } else { Pass 'index.html exists' }
if ($null -eq $manifestRaw) { Fail 'manifest.json missing' } else { Pass 'manifest.json exists' }
if ($null -eq $sw) { Fail 'sw.js missing' } else { Pass 'sw.js exists' }

if ($manifestRaw) {
  try {
    $manifest = $manifestRaw | ConvertFrom-Json
    if ($manifest.display -eq 'standalone') { Pass 'manifest display=standalone' } else { Warn "manifest display=$($manifest.display)" }
    if ($manifest.orientation -match 'portrait') { Pass 'manifest portrait orientation' } else { Warn 'manifest is not portrait-first' }
    $desc = [string]$manifest.description
    if ($desc -match '逆境') { Pass 'manifest advertises adversity' } else { Fail 'manifest does not advertise adversity; four-mode release truth is not synchronized' }
  } catch { Fail "manifest.json invalid JSON: $($_.Exception.Message)" }
}

if ($index) {
  foreach ($term in @('朝','仕事','夜')) {
    if ($index.Contains($term)) { Pass "index contains mode label: $term" } else { Fail "index missing mode label: $term" }
  }
  if ($index.Contains('逆境')) { Pass 'index contains adversity label' } else { Fail 'index contains no verified adversity label' }

  if ($index -match 'audioToggle|音声 ON|音声 OFF') { Pass 'audio toggle marker found' } else { Fail 'audio toggle marker missing' }
  if ($index -match 'audioStop|停止') { Pass 'audio stop marker found' } else { Fail 'audio stop marker missing' }
  if ($index -match 'localStorage') { Pass 'localStorage use detected; privacy inventory required' } else { Pass 'no localStorage marker detected' }

  $storageMatches = [regex]::Matches($index, "localStorage\.(?:getItem|setItem|removeItem)\(['\"]([^'\"]+)['\"]")
  $storageKeys = @($storageMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
  if ($storageKeys.Count -gt 0) {
    Pass ('localStorage keys: ' + ($storageKeys -join ', '))
  }

  foreach ($marker in @('Home','ホーム','Back','戻る')) {
    if ($index.Contains($marker)) { Pass "navigation marker found: $marker"; break }
  }
}

if ($sw) {
  if ($sw -match 'work01') { Pass 'service worker references work assets' } else { Fail 'service worker lacks work asset marker' }
  if ($sw -match 'night01') { Pass 'service worker references night assets' } else { Fail 'service worker lacks night asset marker' }
  if ($sw -match 'advers|逆境') { Pass 'service worker references adversity assets' } else { Fail 'service worker lacks adversity asset marker' }
  if ($sw -match 'cache\.addAll\([^)]+\)\.catch|Promise\.allSettled|catch\(') { Warn 'service worker contains tolerant catch path; verify required cache failures cannot be silently ignored' }
}

$requiredWorkNight = foreach ($mode in @('work','night')) {
  foreach ($n in 1..12) {
    Join-Path $root ("assets/{0}/{0}{1}.jpg" -f $mode, $n.ToString('00'))
  }
}
foreach ($asset in $requiredWorkNight) {
  if (-not (Test-Path $asset)) { Fail "required asset missing: $asset" }
}
if (-not ($requiredWorkNight | Where-Object { -not (Test-Path $_) })) { Pass '24 work/night image assets exist' }

Write-Host '=== DAIMON M02 RELEASE AUDIT ==='
$passes | ForEach-Object { Write-Host "PASS: $_" }
$warnings | ForEach-Object { Write-Warning $_ }
$failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }

Write-Host "PASS=$($passes.Count) WARN=$($warnings.Count) FAIL=$($failures.Count)"

if ($failures.Count -gt 0) { exit 1 }
exit 0
