$ErrorActionPreference='Stop';$server=Split-Path $PSScriptRoot
foreach($module in @('security\MobileSecurity.ps1','adapters\SpecialistRegistry.ps1')){
  . ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server $module))))
}
$root=Join-Path ([IO.Path]::GetTempPath()) ('ai5-specialist-registry-'+[guid]::NewGuid().ToString('N'))
try {
  Initialize-AI5SpecialistRegistry $root

  try{Set-AI5SpecialistHealthRecord -Agent 'not_an_agent' -Connection 'chrome_profile' -CheckedAt ([DateTime]::UtcNow.ToString('o')) -AppMeasurementResult 'PASS' -AppState 'READY'; throw 'allowlist bypass accepted'}catch{if($_.Exception.Message-eq'allowlist bypass accepted'){throw};if($_.Exception.Message-ne'specialist_agent_not_allowed'){throw}}

  try{Set-AI5SpecialistHealthRecord -Agent 'gemini' -Connection 'token=redacted-test-value' -CheckedAt ([DateTime]::UtcNow.ToString('o')); throw 'secret value accepted'}catch{if($_.Exception.Message-eq'secret value accepted'){throw};if($_.Exception.Message-ne'specialist_health_secret_value_rejected'){throw}}

  try{Set-AI5SpecialistHealthRecord -Agent 'gemini' -Connection '' -CheckedAt ''; throw 'missing required fields accepted'}catch{if($_.Exception.Message-eq'missing required fields accepted'){throw};if($_.Exception.Message-ne'specialist_health_agent_connection_checked_at_required'){throw}}

  # Unconfirmed measurement requesting READY must be rejected down to DEGRADED, never READY.
  $unconfirmed=Set-AI5SpecialistHealthRecord -Agent 'gemini' -Connection 'chrome_profile_default' -CheckedAt ([DateTime]::UtcNow.ToString('o')) -AppState 'READY' -AppMeasurementResult 'UNKNOWN'
  if($unconfirmed.app_state-eq'READY'){throw'unconfirmed measurement was accepted as READY'}
  if($unconfirmed.app_state-ne'DEGRADED'){throw'unconfirmed measurement did not degrade as expected'}
  $unconfirmedRead=Get-AI5SpecialistHealth 'gemini'
  if($unconfirmedRead.appState-eq'READY'){throw'unconfirmed measurement surfaced as READY on read'}

  # Stale measurement (outside the freshness window) requesting READY must fall back to OFFLINE even with a PASS result.
  $staleCheckedAt=[DateTime]::UtcNow.AddHours(-2).ToString('o')
  $stale=Set-AI5SpecialistHealthRecord -Agent 'gemini' -Connection 'chrome_profile_default' -CheckedAt $staleCheckedAt -AppState 'READY' -AppMeasurementResult 'PASS'
  if($stale.app_state-ne'OFFLINE'){throw'stale PASS measurement was not downgraded to OFFLINE'}

  # Fresh PASS measurement is the only path allowed to report READY.
  $fresh=Set-AI5SpecialistHealthRecord -Agent 'notebooklm' -Connection 'chrome_profile_default' -CheckedAt ([DateTime]::UtcNow.ToString('o')) -AppState 'READY' -AppMeasurementResult 'PASS' -Quota '10/50'
  if($fresh.app_state-ne'READY'){throw'fresh PASS measurement was not accepted as READY'}
  $freshRead=Get-AI5SpecialistHealth 'notebooklm'
  if(!$freshRead.available-or$freshRead.appState-ne'READY'-or$freshRead.quota-ne'10/50'){throw'fresh READY record did not round-trip through Get-AI5SpecialistHealth'}

  # READY must expire when read, even when the persisted record was fresh at write time.
  $notebookPath=Join-Path (Join-Path $root 'runtime\agents') 'notebooklm.json'
  $persisted=Get-Content -Raw -Encoding UTF8 $notebookPath|ConvertFrom-Json
  $persisted.checked_at=[DateTime]::UtcNow.AddHours(-2).ToString('o')
  $persisted|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 -LiteralPath $notebookPath
  $expiredRead=Get-AI5SpecialistHealth 'notebooklm'
  if($expiredRead.available-or$expiredRead.appState-ne'OFFLINE'-or$expiredRead.connection-ne'stale'){throw'READY record did not expire on read'}

  'SPECIALIST_REGISTRY_TESTS_OK'
} finally {
  if(Test-Path $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
