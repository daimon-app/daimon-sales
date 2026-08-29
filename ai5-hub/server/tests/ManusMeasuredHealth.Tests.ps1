$ErrorActionPreference='Stop'
$server=Split-Path $PSScriptRoot
foreach($module in @('security\MobileSecurity.ps1','adapters\SpecialistRegistry.ps1','adapters\ManusAdapter.ps1')){
  . ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server $module))))
}
$root=Join-Path ([IO.Path]::GetTempPath()) ('ai5-manus-health-'+[guid]::NewGuid().ToString('N'))
try {
  Initialize-AI5SpecialistRegistry $root
  Register-AI5ManusMeasuredHealth -Connection 'windows_app' -CheckedAt ([DateTime]::UtcNow.ToString('o')) -PreferredRoute 'WEB' -AppMeasurementResult 'PASS' -WebMeasurementResult 'FAIL' -AppAutomation 'computer_use' -AppIdentity 'official_store_app' -AppVersion '1.7.2.0' -Publisher 'ManusAI' -InstallSource 'Microsoft Store' -AppAuthenticated $true | Out-Null
  $appHealth=Get-AI5ManusHealth
  if(!$appHealth.available-or$appHealth.app.state-ne'READY'-or$appHealth.web.state-ne'DEGRADED'){throw'app measured health did not round-trip'}
  if($appHealth.route.selected-ne'APP'-or$appHealth.route.fallback-ne''){throw'failed WEB route was selected or exposed as fallback'}

  Register-AI5ManusMeasuredHealth -Connection 'chrome_web+windows_app' -CheckedAt ([DateTime]::UtcNow.ToString('o')) -PreferredRoute 'WEB' -AppMeasurementResult 'PASS' -WebMeasurementResult 'PASS' -AppAutomation 'computer_use' -AppIdentity 'official_store_app' -AppVersion '1.7.2.0' -Publisher 'ManusAI' -InstallSource 'Microsoft Store' -AppAuthenticated $true -WebAuthenticated $true | Out-Null
  $webHealth=Get-AI5ManusHealth
  if(!$webHealth.available-or$webHealth.route.selected-ne'WEB'-or$webHealth.route.fallback-ne'APP'){throw'WEB preferred measured health invalid'}

  'MANUS_MEASURED_HEALTH_TESTS_OK'
} finally {
  if(Test-Path $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
