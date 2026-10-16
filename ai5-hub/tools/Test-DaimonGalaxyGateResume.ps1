# Test: Galaxy connection is detected and the waiting GALAXY task auto-resumes without an Owner prompt.
# Uses a fake adb and a temp Result Bus; touches nothing real.
$ErrorActionPreference = 'Stop'
$sut = Join-Path $PSScriptRoot 'Invoke-DaimonGalaxyPreflight.ps1'
$realResume = 'C:\Users\teppe\Documents\GitHub\daimon-sales\ai5-github-result-bus\worker\Resume-AI5OwnerGateTask.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('daimon-galaxy-gate-' + [guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Write-Json($value, [string]$path) { [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 10), $utf8) }
function Read-Task([string]$id) { [IO.File]::ReadAllText((Join-Path $root "bus\tasks\$id.json"), $utf8) | ConvertFrom-Json }
try {
  New-Item -ItemType Directory -Force (Join-Path $root 'bus\tasks'), (Join-Path $root 'worker'), (Join-Path $root 'out') | Out-Null
  Copy-Item $realResume (Join-Path $root 'worker')
  $noDevice = Join-Path $root 'adb-none.cmd'; $oneDevice = Join-Path $root 'adb-one.cmd'
  Set-Content $noDevice "@echo off`r`nif `"%1`"==`"devices`" echo List of devices attached`r`nexit /b 0" -Encoding ascii
  Set-Content $oneDevice "@echo off`r`nif `"%1`"==`"devices`" (echo List of devices attached& echo FAKE123 device)`r`nexit /b 0" -Encoding ascii
  $created = [DateTimeOffset]::Now.AddMinutes(-1).ToString('o')
  foreach ($t in @(@{ id = 'GALAXY-TEST-01'; gate = 'GALAXY_DEVICE_CONNECT' }, @{ id = 'GALAXY-TEST-02'; gate = 'SOME_OTHER_GATE' })) {
    Write-Json ([ordered]@{ task_id = $t.id; status = 'WAITING_OWNER_GATE'; owner_gate_id = $t.gate; auto_resume_after_owner_gate = $true
      resume_status_after_owner_gate = 'QUEUED'; decision_version = 'v1'; created_at = $created; updated_at = $created }) (Join-Path $root "bus\tasks\$($t.id).json")
  }
  $common = @{ BusRoot = (Join-Path $root 'out'); ResultBusRepo = $root }

  & $sut @common -Adb $noDevice -GateTaskId 'GALAXY-TEST-01' | Out-Null
  Assert ((Read-Task 'GALAXY-TEST-01').status -eq 'WAITING_OWNER_GATE') 'resumed without a device'

  $out = (& $sut @common -Adb $oneDevice -GateTaskId 'GALAXY-TEST-01') -join "`n"
  Assert ($out -match 'OWNER_GATE_AUTO_RESUMED') 'connected device did not auto-resume'
  Assert ((Read-Task 'GALAXY-TEST-01').status -eq 'QUEUED') 'task not QUEUED after resume'
  Assert (Test-Path (Join-Path $root 'bus\state\owner-gate-resume-receipts\GALAXY-TEST-01.json')) 'resume receipt missing'

  $again = (& $sut @common -Adb $oneDevice -GateTaskId 'GALAXY-TEST-01') -join "`n"
  Assert ($again -notmatch 'OWNER_GATE_AUTO_RESUMED') 'duplicate resume'

  & $sut @common -Adb $oneDevice -GateTaskId 'GALAXY-TEST-02' | Out-Null
  Assert ((Read-Task 'GALAXY-TEST-02').status -eq 'WAITING_OWNER_GATE') 'foreign gate was resumed'

  [pscustomobject][ordered]@{ overall = 'PASS'; no_device_stays_waiting = 'PASS'; connected_auto_resume = 'PASS'
    receipt_written = 'PASS'; duplicate_guard = 'PASS'; foreign_gate_untouched = 'PASS'; secret_recorded = 0 } | ConvertTo-Json -Compress
} finally { if (Test-Path $root) { Remove-Item -LiteralPath $root -Recurse -Force } }
