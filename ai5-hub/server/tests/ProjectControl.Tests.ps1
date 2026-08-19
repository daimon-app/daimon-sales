$ErrorActionPreference='Stop'
function Assert-PC($Condition,[string]$Message){if(!$Condition){throw $Message}}
$appRoot=Split-Path (Split-Path $PSScriptRoot);$module=Join-Path $appRoot 'server\project-control\ProjectControl.ps1'
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 $module)))
$temp=Join-Path ([IO.Path]::GetTempPath()) ('ai5-pc-'+[guid]::NewGuid().ToString('N'));$server=Join-Path $temp 'server';$app=Join-Path $temp 'app'
try{
  New-Item -ItemType Directory -Force (Join-Path $app 'project-control\projects')|Out-Null
  Copy-Item (Join-Path $appRoot 'project-control\registry.json') (Join-Path $app 'project-control\registry.json')
  Copy-Item (Join-Path $appRoot 'project-control\projects\*.json') (Join-Path $app 'project-control\projects')
  Initialize-AI5ProjectControl $server $app
  $body=[pscustomobject]@{projectId='test-project';name='Test Project';repository='repo'};$p=New-AI5Project $body
  Assert-PC (!$p.autoExecution.enabled) 'Project add / AUTO default OFF failed'
  $p=Set-AI5ProjectAuto $p 'DRY_RUN';Assert-PC ($p.autoExecution.enabled-and$p.autoExecution.mode-eq'DRY_RUN') 'DRY RUN failed';$p=Set-AI5ProjectAuto $p 'OFF';Assert-PC (!$p.autoExecution.enabled) 'AUTO OFF failed'
  $p=Set-AI5ProjectState $p ([pscustomobject]@{status='BLOCKED';blockedBy='ZERO';stopCode='ZERO_STOPPED'})
  Assert-PC ($p.timestamps.stoppedAt-and$p.blockedBy-eq'ZERO') 'stoppedAt / ZERO_STOPPED failed'
  $p=Set-AI5ProjectState $p ([pscustomobject]@{status='RUNNING';blockedBy='NONE';stopCode='NONE'});Assert-PC ($p.timestamps.resumedAt-and$p.timestamps.workStartedAt) 'resumedAt / workStartedAt failed'
  $p=Set-AI5ProjectState $p ([pscustomobject]@{status='COMPLETED'});Assert-PC $p.timestamps.workCompletedAt 'workCompletedAt failed'
  $p=Set-AI5ProjectState $p ([pscustomobject]@{status='BLOCKED';blockedBy='CODEX';stopCode='CODEX_STOPPED'});Assert-PC ($p.stopCode-eq'CODEX_STOPPED') 'CODEX_STOPPED failed'
  $p=Set-AI5ProjectState $p ([pscustomobject]@{status='WAITING';blockedBy='TEPPEI';stopCode='TEPPEI_WAITING'});Assert-PC ($p.stopCode-eq'TEPPEI_WAITING') 'TEPPEI_WAITING failed'
  $p=Set-AI5ProjectState $p ([pscustomobject]@{status='WAITING';blockedBy='NONE';stopCode='ALL_AI_DONE_BUT_IDLE'});Assert-PC ($p.stopCode-eq'ALL_AI_DONE_BUT_IDLE') 'ALL_AI_DONE_BUT_IDLE failed'
  foreach($agent in @('zero','codex','claude','gemini','manus','notebooklm')){$p.aiState.$agent='DONE'};$p.nextAction='Next build';$p.status='READY';$p=Update-AI5ProjectStopCode $p;Assert-PC ($p.stopCode-eq'ALL_AI_DONE_BUT_IDLE') 'automatic idle detection failed'
  $p.autoExecution.enabled=$true;$p.autoExecution.mode='LIVE';$p.status='READY';$p.blockedBy='NONE';$p.repository.sync.state='SYNCED';$p.executionPolicy.consecutiveFailures=2;Assert-PC ((Test-AI5ProjectExecution $p).reason-eq'ERROR_LOOP_STOP') 'ERROR_LOOP_STOP failed'
  $p.executionPolicy.consecutiveFailures=0;$p.executionPolicy.costClass='HIGH';Assert-PC ((Test-AI5ProjectExecution $p).reason-eq'CREDIT_PROTECTION_STOP') 'CREDIT_PROTECTION_STOP failed'
  $p.executionPolicy.costClass='NORMAL';$p.executionPolicy.autoRunsDate=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow,'Tokyo Standard Time').ToString('yyyy-MM-dd');$p.executionPolicy.autoRunsToday=3;Assert-PC ((Test-AI5ProjectExecution $p).reason-eq'CREDIT_PROTECTION_STOP') 'daily protection failed'
  $p.executionPolicy.autoRunsToday=0;$p.autoExecution.enabled=$false;$p.autoExecution.mode='OFF';Assert-PC ((Test-AI5ProjectExecution $p).reason-eq'AUTO_OFF') 'AUTO OFF execution gate failed'
  $p=Set-AI5ProjectState $p ([pscustomobject]@{currentTask='OAuth production release';status='READY'});Assert-PC ($p.status-eq'APPROVAL_REQUIRED'-and$p.blockedBy-eq'TEPPEI') 'approval gate bypassed'
  $lock=Enter-AI5ProjectLock 'test-project' 'CODEX' 'task-1';$blocked=$false;try{Enter-AI5ProjectLock 'test-project' 'CODEX' 'task-2'|Out-Null}catch{$blocked=$true};Assert-PC $blocked 'Single Writer failed';Exit-AI5ProjectLock 'test-project' 'task-1'
  $p.phase='PUBLISHED';$p.status='RUNNING';Save-AI5Project $p;$p=Set-AI5ProjectState $p ([pscustomobject]@{phase='PUBLISHED';status='PUBLISHED'});$published=$p.timestamps.publishedAt;$p=Set-AI5ProjectState $p ([pscustomobject]@{phase='FIX_REQUIRED';status='READY'});$p=Set-AI5ProjectState $p ([pscustomobject]@{phase='PUBLISHED';status='PUBLISHED'});Assert-PC ($p.timestamps.publishedAt-eq$published-and$p.history.Count-gt10) 'sales lifecycle/history preservation failed'
  for($i=1;$i-le100;$i++){New-AI5Project ([pscustomobject]@{projectId=('bulk-{0:d3}'-f$i);name="Bulk $i";repository=''})|Out-Null};Assert-PC ((Get-AI5Projects).Count-ge103) '100 project display source failed'
  $offlineShell=Get-Content -Raw (Join-Path $appRoot 'app.js');Assert-PC ($offlineShell-match'PCオフライン'-and$offlineShell-match'refreshProjects') 'Offline UI/regression marker failed'
  $sw=Get-Content -Raw (Join-Path $appRoot 'service-worker.js');Assert-PC ($sw-match'fetch'-and$sw-match'ai5-hub-v46') 'PWA offline cache version failed'
  $appJs=Get-Content -Raw (Join-Path $appRoot 'app.js');Assert-PC ($appJs-match"value.error==='csrf'"-and$appJs-match'allowCsrfRefresh') 'CSRF restart recovery missing'
  'PROJECT_CONTROL_TESTS_OK'
}finally{if(Test-Path $temp){Remove-Item -Recurse -Force $temp}}
