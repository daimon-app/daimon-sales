$ErrorActionPreference='Stop';$server=Split-Path $PSScriptRoot
foreach($module in @('storage\Store.ps1','orchestrator\TaskEngine.ps1','orchestrator\AutonomousLoop.ps1','github-bus\GitHubResultLoop.ps1','adapters\ManusAdapter.ps1')){
  . ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server $module))))
}
$serverRaw=Get-Content -Raw -Encoding UTF8 (Join-Path $server 'server.ps1')
$startMarker='function Update-State(';$endMarker='function Restore-AI5TaskFromStoredCodexResult'
$startIdx=$serverRaw.IndexOf($startMarker);$endIdx=$serverRaw.IndexOf($endMarker)
if($startIdx-lt0-or$endIdx-lt0){throw 'server.ps1 recovery function markers not found'}
. ([ScriptBlock]::Create($serverRaw.Substring($startIdx,$endIdx-$startIdx)))

$root=Join-Path ([IO.Path]::GetTempPath()) ('ai5-manus-recovery-'+[guid]::NewGuid().ToString('N'))
try {
  Initialize-AI5Store $root;Initialize-AI5GitHubResultLoop $root
  $manusHealth=[pscustomobject]@{available=$true;preferredRoute='WEB';app=[pscustomobject]@{state='READY'};web=[pscustomobject]@{state='READY'}}

  $passId='local-manus-recovery-pass'
  $localPass=[pscustomobject]@{taskId=$passId;assignedPrimary='manus';status='running';canonical_status='RUNNING';requiresApproval=$false;attempt=0;max_attempts=3;manus_dispatch=(New-AI5ManusDispatchPlan ([pscustomobject]@{taskId=$passId}) $manusHealth);timeline=@();result=$null;validation=[ordered]@{};updatedAt=[DateTime]::UtcNow.ToString('o')}
  Save-AI5Task $localPass
  New-AI5GitHubBusTask ([pscustomobject]@{task_id=$passId;project_id='p';assigned_ai='manus';writer='manus';objective='LP QA';instructions='WEB read-only';max_retry=3})|Out-Null
  New-AI5GitHubBusResult ([pscustomobject]@{task_id=$passId;ai='manus';result='BLOCKED';summary='WEB failed';blockers=@('BLOCKED_BROWSER')})|Out-Null
  Invoke-AI5GitHubResultCollector|Out-Null
  Invoke-AI5ManusResultRecovery
  $afterWeb=Get-AI5Task $passId
  if($afterWeb.status-ne'retrying'-or$afterWeb.manus_dispatch.route-ne'APP'-or$afterWeb.manus_dispatch.fallback-ne''){throw 'scenario1: WEB BLOCKED did not reroute to a tracked APP retry'}
  $lineAfterWeb=@($afterWeb.line_messages).Count;$reportAfterWeb=@($afterWeb.agent_reports).Count

  Invoke-AI5ManusResultRecovery
  $afterRepoll=Get-AI5Task $passId
  if($afterRepoll.status-ne'retrying'-or$afterRepoll.manus_dispatch.route-ne'APP'){throw 'scenario2: polling again before the APP result mutated route/status'}
  if(@($afterRepoll.line_messages).Count-ne$lineAfterWeb-or@($afterRepoll.agent_reports).Count-ne$reportAfterWeb){throw 'scenario2/5: polling again before the APP result duplicated LINE/report entries'}

  $appRetry=Get-AI5GitHubBusTasks|Where-Object{$_.parent_task_id-eq$passId}|Select-Object -First 1
  if(!$appRetry-or$appRetry.assigned_ai-ne'manus'){throw 'scenario1: Collector did not create the expected APP retry bus task'}
  New-AI5GitHubBusResult ([pscustomobject]@{task_id=$appRetry.task_id;ai='manus';result='PASS';summary='APP QA PASS';evidence=@('screenshot');tests=@('PASS')})|Out-Null
  Invoke-AI5GitHubResultCollector|Out-Null
  Invoke-AI5ManusResultRecovery
  $completed=Get-AI5Task $passId
  if($completed.status-ne'completed'-or$completed.canonical_status-ne'COMPLETED'){throw 'scenario3: APP PASS did not complete the parent task exactly once'}
  $completedLine=@($completed.line_messages).Count;$completedReport=@($completed.agent_reports).Count

  Invoke-AI5ManusResultRecovery
  $completedAgain=Get-AI5Task $passId
  if(@($completedAgain.line_messages).Count-ne$completedLine-or@($completedAgain.agent_reports).Count-ne$completedReport){throw 'scenario5: polling a completed task duplicated LINE/report entries'}

  $blockedId='local-manus-recovery-blocked'
  $localBlocked=[pscustomobject]@{taskId=$blockedId;assignedPrimary='manus';status='running';canonical_status='RUNNING';requiresApproval=$false;attempt=0;max_attempts=3;manus_dispatch=(New-AI5ManusDispatchPlan ([pscustomobject]@{taskId=$blockedId}) $manusHealth);timeline=@();result=$null;validation=[ordered]@{};updatedAt=[DateTime]::UtcNow.ToString('o')}
  Save-AI5Task $localBlocked
  New-AI5GitHubBusTask ([pscustomobject]@{task_id=$blockedId;project_id='p';assigned_ai='manus';writer='manus';objective='LP QA';instructions='WEB read-only';max_retry=3})|Out-Null
  New-AI5GitHubBusResult ([pscustomobject]@{task_id=$blockedId;ai='manus';result='BLOCKED';summary='WEB failed';blockers=@('BLOCKED_BROWSER')})|Out-Null
  Invoke-AI5GitHubResultCollector|Out-Null
  Invoke-AI5ManusResultRecovery
  $blockedAfterWeb=Get-AI5Task $blockedId
  if($blockedAfterWeb.status-ne'retrying'-or$blockedAfterWeb.manus_dispatch.route-ne'APP'){throw 'scenario4-setup: WEB BLOCKED did not reroute the second task to APP'}
  $blockedAppRetry=Get-AI5GitHubBusTasks|Where-Object{$_.parent_task_id-eq$blockedId}|Select-Object -First 1
  New-AI5GitHubBusResult ([pscustomobject]@{task_id=$blockedAppRetry.task_id;ai='manus';result='BLOCKED';summary='APP failed';blockers=@('BLOCKED_BROWSER')})|Out-Null
  Invoke-AI5GitHubResultCollector|Out-Null
  $grandchild=Get-AI5GitHubBusTasks|Where-Object{$_.parent_task_id-eq$blockedAppRetry.task_id}|Select-Object -First 1
  if(!$grandchild-or$grandchild.assigned_ai-ne'claude'){throw 'scenario4-setup: Collector did not create the expected non-Manus fallback after APP failure'}
  Invoke-AI5ManusResultRecovery
  $blockedFinal=Get-AI5Task $blockedId
  if($blockedFinal.canonical_status-ne'BLOCKED'-or$blockedFinal.errorType-ne'manus_exhausted_redispatched'){throw 'scenario4: APP failure after WEB failure was not represented as an accurate REDISPATCH/BLOCKED state'}
  if($blockedFinal.manus_dispatch.fallbackTaskId-ne$grandchild.task_id-or$blockedFinal.manus_dispatch.fallbackAssignedAi-ne'claude'){throw 'scenario4: lineage to the non-Manus fallback task was lost'}
  if($blockedFinal.assignedPrimary-ne'manus'){throw 'scenario4: Codex worker was incorrectly involved on the Manus path'}
  $blockedLine=@($blockedFinal.line_messages).Count;$blockedReport=@($blockedFinal.agent_reports).Count
  Invoke-AI5ManusResultRecovery
  $blockedAgain=Get-AI5Task $blockedId
  if(@($blockedAgain.line_messages).Count-ne$blockedLine-or@($blockedAgain.agent_reports).Count-ne$blockedReport){throw 'scenario5: polling after the exhausted redispatch duplicated LINE/report entries'}

  'MANUS_RESULT_RECOVERY_TESTS_OK'
} finally {
  if(Test-Path $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
