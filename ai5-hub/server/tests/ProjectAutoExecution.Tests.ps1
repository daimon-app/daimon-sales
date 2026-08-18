$ErrorActionPreference='Stop'
function Assert-Auto($ok,[string]$message){if(!$ok){throw $message}}
$appRoot=Split-Path (Split-Path $PSScriptRoot);. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'server\project-control\ProjectControl.ps1'))))
$script:MockTasks=@{}
function New-Task($body,$idem){[pscustomobject]@{taskId=$body.taskId;task_id=$body.taskId;message=$body.message;status='queued';result=$null;route=@{risk='low'};requiresApproval=$false}}
function Save-AI5Task($task){$script:MockTasks[$task.taskId]=$task}
function Get-AI5Task($id){$script:MockTasks[$id]}
function Dispatch-Task($task){$task.status='running';Save-AI5Task $task}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('ai5-auto-'+[guid]::NewGuid().ToString('N'));$server=Join-Path $temp 'server';$app=Join-Path $temp 'app'
try{
  New-Item -ItemType Directory -Force (Join-Path $app 'project-control\projects')|Out-Null;Copy-Item (Join-Path $appRoot 'project-control\registry.json') (Join-Path $app 'project-control\registry.json');Copy-Item (Join-Path $appRoot 'project-control\projects\*.json') (Join-Path $app 'project-control\projects');Initialize-AI5ProjectControl $server $app
  $p=New-AI5Project ([pscustomobject]@{projectId='auto-test';name='Auto Test';repository='repo'});$p.status='READY';$p.nextAction='Run safe tests';$p.repository.sync.state='SYNCED';Save-AI5Project $p
  foreach($case in @(@('SYNCED',0,0,$false),@('LOCAL_AHEAD',1,0,$false),@('REMOTE_AHEAD',0,1,$false),@('DIVERGED',1,1,$false),@('DIRTY',0,0,$true))){$s=[pscustomobject]@{state=$case[0];localHead='a';remoteHead='b';defaultHead='c';activeBranch='feat/test';ahead=$case[1];behind=$case[2];dirty=$case[3];checkedAt=Get-PCNow;error=''};$p=Sync-AI5ProjectGit $p $s $false;Assert-Auto ($p.repository.sync.state-eq$case[0]) "sync state $($case[0]) failed"}
  $unavailable=[pscustomobject]@{state='REMOTE_UNAVAILABLE';localHead='a';remoteHead='';defaultHead='';activeBranch='feat/test';ahead=0;behind=0;dirty=$false;checkedAt=Get-PCNow;error='offline'};$p=Sync-AI5ProjectGit $p $unavailable $false;Assert-Auto ($p.stopCode-eq'GITHUB_SYNC_WAIT') 'GITHUB_SYNC_WAIT failed'
  $p.repository.sync.state='SYNCED';$p.blockedBy='NONE';$p.stopCode='NONE';$p.status='READY';$p=Set-AI5ProjectAuto $p 'OFF';Assert-Auto (!(Submit-AI5ProjectWork $p).submitted) 'AUTO OFF submitted'
  $p=Set-AI5ProjectAuto $p 'DRY_RUN';$dry=Submit-AI5ProjectWork $p;Assert-Auto ($dry.dryRun-and$script:MockTasks.Count-eq0) 'DRY RUN executed'
  $p=Set-AI5ProjectAuto $p 'LIVE';$live=Submit-AI5ProjectWork $p;Assert-Auto ($live.submitted-and$script:MockTasks.Count-eq1-and$p.aiState.codex-eq'RUNNING') 'LIVE queue failed'
  $task=$script:MockTasks[$live.taskId];$task.status='completed';$task.result=[pscustomobject]@{status='SUCCESS';summary='ok';failureReason='';next_action=''};Save-AI5Task $task;$p=Recover-AI5ProjectResult $p;Assert-Auto ($p.aiState.codex-eq'DONE'-and$p.executionPolicy.retryCount-eq0) 'SUCCESS recovery failed'
  $p.execution.taskId='partial';$p.execution.lockId='';$script:MockTasks.partial=[pscustomobject]@{taskId='partial';status='completed';result=[pscustomobject]@{status='PARTIAL';summary='unfinished';next_action='finish'}};$p=Recover-AI5ProjectResult $p;Assert-Auto ($p.status-eq'WAITING'-and$p.nextAction-eq'finish') 'PARTIAL recovery failed'
  $p.execution.taskId='fail';$script:MockTasks.fail=[pscustomobject]@{taskId='fail';status='failed';errorType='task_failed';result=[pscustomobject]@{status='FAIL';summary='bad';failureReason='same'}};$p=Recover-AI5ProjectResult $p;$p.execution.taskId='fail2';$script:MockTasks.fail2=[pscustomobject]@{taskId='fail2';status='failed';errorType='task_failed';result=[pscustomobject]@{status='FAIL';summary='bad';failureReason='same'}};$p=Recover-AI5ProjectResult $p;Assert-Auto ($p.executionPolicy.consecutiveFailures-eq2-and(Test-AI5ProjectExecution $p).reason-eq'ERROR_LOOP_STOP') 'FAIL x2 protection failed'
  $p.execution.taskId='timeout';$script:MockTasks.timeout=[pscustomobject]@{taskId='timeout';status='failed';errorType='timeout';result=[pscustomobject]@{status='TIMEOUT';summary='timeout';failureReason='timeout'}};$p=Recover-AI5ProjectResult $p;Assert-Auto ($p.blockedBy-eq'SYSTEM'-and$p.stopCode-eq'SYSTEM'-and$p.execution.recoveryRequired) 'timeout recovery failed'
  $p.currentTask='OAuth release';$p.status='READY';$p=Set-AI5ProjectState $p ([pscustomobject]@{});Assert-Auto ($p.status-eq'APPROVAL_REQUIRED') 'approval stop failed'
  $p.currentTask='safe';$p.status='READY';$p.blockedBy='NONE';$p.execution.recoveryRequired=$false;$p.execution.taskId='';$p.repository.sync.state='SYNCED';$p.executionPolicy.costClass='HIGH';$p.autoExecution.mode='LIVE';$p.autoExecution.enabled=$true;Assert-Auto ((Test-AI5ProjectExecution $p).reason-eq'CREDIT_PROTECTION_STOP') 'HIGH stop failed'
  $candidates=Get-AI5RepositoryCandidates 'owner' @("repo`tfalse","new-repo`tfalse","old-repo`ttrue");$newCandidate=@($candidates|Where-Object{$_.name-eq'new-repo'})[0];Assert-Auto ($newCandidate.state-eq'UNREGISTERED'-and!(Get-AI5Project 'new-repo')) 'repository candidate auto-added'
  for($i=1;$i-le100;$i++){New-AI5Project ([pscustomobject]@{projectId="scan-$i";name="Scan $i";repository=''})|Out-Null};$scan=Invoke-AI5ProjectScan -Fetch $false -DryRun $true;Assert-Auto ($scan.projects.Count-ge103-and$scan.dispatched-le1) '100 project scheduler failed'
  $scheduler=Get-AI5SchedulerStatus;Assert-Auto ($scheduler.lastScan-and$scheduler.nextScan) 'scheduler persistence failed'
  'PROJECT_AUTO_EXECUTION_TESTS_OK'
}finally{if(Test-Path $temp){Remove-Item -Recurse -Force $temp}}
