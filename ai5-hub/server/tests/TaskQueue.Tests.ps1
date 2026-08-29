$ErrorActionPreference='Stop';$server=Split-Path $PSScriptRoot;. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'orchestrator\TaskQueue.ps1'))))
function T($id,$project,$status,$type='code',$git=$true,$message='change'){[pscustomobject]@{taskId=$id;project_id=$project;status=$status;message=$message;route=[pscustomobject]@{workType=$type;gitChange=$git;externalOperation=$false}}}
$active=T 'one' 'ai5-hub' 'running';$next=T 'two' 'ai5-hub' 'queued';$other=T 'three' 'other' 'queued';$read=T 'four' 'ai5-hub' 'queued' 'review' $false 'read-only review'
if((Get-AI5TaskQueueDecision $next @($active) @()).action-ne'QUEUE'){throw'same project writer was not queued'}
if((Get-AI5TaskQueueDecision $other @($active) @()).action-ne'DISPATCH'){throw'other project was blocked'}
if((Get-AI5TaskQueueDecision $read @($active) @()).reason-ne'READ_ONLY_PARALLEL'){throw'read-only task was blocked'}
if((Get-AI5TaskQueueDecision $next @() @([pscustomobject]@{projectId='ai5-hub'})).action-ne'QUEUE'){throw'project lock ignored'}
$negativeWrite=[pscustomobject]@{taskId='negative-write';project_id='ai5-hub';message='Git状態をread-onlyで確認し、変更せず結果だけ返してください';route=[pscustomobject]@{gitChange=$false;externalOperation=$false;workType='pc_task'}}
if((Get-AI5TaskQueueDecision $negativeWrite @($active) @()).reason-ne'READ_ONLY_PARALLEL'){throw'negative write wording was treated as a write request'}
$stale=[pscustomobject]@{taskId='stale';project_id='ai5-hub';message='old';status='running';updatedAt=[DateTime]::UtcNow.AddHours(-2).ToString('o');route=[pscustomobject]@{gitChange=$true;externalOperation=$false;workType='code'}}
if((Get-AI5TaskQueueDecision $next @($stale) @()).action-ne'DISPATCH'){throw 'stale task retained writer ownership'}
'TASK_QUEUE_TESTS_OK'
