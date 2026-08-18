function Get-PCGuid{[guid]::NewGuid().ToString('N')}
function Get-PCElapsedSeconds([string]$FromIso){if(!$FromIso){return 0};[Math]::Max(0,([DateTimeOffset]::Now-[DateTimeOffset]::Parse($FromIso)).TotalSeconds)}

function Get-AI5ProjectTiming($Project){
  $t=$Project.timing
  if(!$t){return [ordered]@{status='STOPPED';accumulatedRunningSeconds=0;accumulatedPausedSeconds=0;runStartedAt='';pausedAt='';lastPauseAt='';lastResumeAt=''}}
  $running=[double]$t.accumulatedRunningSeconds+$(if($t.status-eq'RUNNING'-and$t.runStartedAt){Get-PCElapsedSeconds $t.runStartedAt}else{0})
  $paused=[double]$t.accumulatedPausedSeconds+$(if($t.status-eq'PAUSED'-and$t.pausedAt){Get-PCElapsedSeconds $t.pausedAt}else{0})
  [ordered]@{status=$t.status;accumulatedRunningSeconds=[Math]::Round($running,1);accumulatedPausedSeconds=[Math]::Round($paused,1);runStartedAt=$t.runStartedAt;pausedAt=$t.pausedAt;lastPauseAt=$t.lastPauseAt;lastResumeAt=$t.lastResumeAt}
}

function Set-AI5ProjectTimingStatus($Project,[string]$NewStatus){
  $t=$Project.timing
  if(!$t){$Project|Add-Member -NotePropertyName timing -NotePropertyValue ([pscustomobject]@{status='STOPPED';accumulatedRunningSeconds=0;accumulatedPausedSeconds=0;runStartedAt='';pausedAt='';lastPauseAt='';lastResumeAt='';preStatus=''}) -Force;$t=$Project.timing}
  if($t.status-eq'RUNNING'-and$t.runStartedAt){$t.accumulatedRunningSeconds=[double]$t.accumulatedRunningSeconds+(Get-PCElapsedSeconds $t.runStartedAt)}
  if($t.status-eq'PAUSED'-and$t.pausedAt){$t.accumulatedPausedSeconds=[double]$t.accumulatedPausedSeconds+(Get-PCElapsedSeconds $t.pausedAt)}
  $t.runStartedAt='';$t.pausedAt=''
  if($NewStatus-eq'RUNNING'){$t.runStartedAt=Get-PCNow;$t.lastResumeAt=Get-PCNow}
  elseif($NewStatus-eq'PAUSED'){$t.pausedAt=Get-PCNow;$t.lastPauseAt=Get-PCNow}
  $t.status=$NewStatus
  $Project
}

function Get-AI5ProjectApprovalCount($Project){
  if(!(Get-Command Get-AI5Tasks -ErrorAction SilentlyContinue)){return 0}
  @(Get-AI5Tasks 500|Where-Object{$_.status-eq'waiting_approval'-and$_.projectContext-and$_.projectContext.projectId-eq$Project.projectId}).Count
}

function Get-AI5ProjectRoomRepoPath($Project){
  if($Project.repository.worktree){return [IO.Path]::GetFullPath($Project.repository.worktree)}
  Get-AI5ProjectRepoPath $Project
}

function Test-AI5ProjectRoomRevalidate($Project){
  $issues=@()
  $repoPath=Get-AI5ProjectRoomRepoPath $Project
  if($Project.repository.linkState-eq'LINKED'){
    if(!(Test-Path (Join-Path $repoPath '.git'))){$issues+='repository_missing'}
    else{
      $branch=((& git -C $repoPath branch --show-current 2>$null)-join'').Trim()
      if($Project.repository.activeBranch-and$branch-and$branch-ne$Project.repository.activeBranch){$issues+='branch_mismatch'}
    }
  }
  if($Project.repository.worktree-and!(Test-Path $Project.repository.worktree)){$issues+='worktree_missing'}
  if($Project.execution.taskId){
    if(!(Get-Command Get-AI5Task -ErrorAction SilentlyContinue)){$issues+='task_unverifiable'}
    else{$task=Get-AI5Task $Project.execution.taskId;if(!$task){$issues+='task_missing'}}
  }
  if($Project.execution.lockId){
    $lockPath=Join-Path $script:PCLocks ((Get-PCSafeId $Project.projectId)+'.lock')
    if(!(Test-Path $lockPath)){$issues+='lock_missing'}
    else{$lock=Read-PCJson $lockPath;if($lock.taskId-ne$Project.execution.lockId){$issues+='lock_mismatch'}}
  }
  ,@($issues)
}

function Pause-AI5Project($Project,[string]$Actor='TEPPEI'){
  if($Project.status-eq'PAUSED'){return $Project}
  $issues=Test-AI5ProjectRoomRevalidate $Project
  if($issues.Count){throw ('pause_rejected:'+($issues-join','))}
  $Project.timing.preStatus=$Project.status
  if('control'-notin$Project.psobject.Properties.Name){$Project|Add-Member control ([pscustomobject]@{pauseRequested=$false;emergencyStopRequested=$false})}
  $Project.control.pauseRequested=$true
  Set-AI5ProjectTimingStatus $Project 'PAUSED'|Out-Null
  $Project.status='PAUSED';$Project.blockedBy='TEPPEI';$Project.stopCode='NORMAL_WAIT';$Project.timestamps.stoppedAt=Get-PCNow
  Write-PCLog $Project 'PAUSED' "actor=$Actor"
  Save-AI5Project $Project;$Project
}

function Resume-AI5Project($Project,[string]$Actor='TEPPEI'){
  if($Project.status-ne'PAUSED'){throw'not_paused'}
  $issues=Test-AI5ProjectRoomRevalidate $Project
  if($issues.Count){throw ('resume_rejected:'+($issues-join','))}
  Set-AI5ProjectTimingStatus $Project 'RUNNING'|Out-Null
  if($Project.control){$Project.control.pauseRequested=$false;$Project.control.emergencyStopRequested=$false}
  $Project.status=$(if($Project.timing.preStatus){$Project.timing.preStatus}else{'RUNNING'})
  $Project.timing.preStatus=''
  $Project.blockedBy='NONE';$Project.stopCode='NONE';$Project.timestamps.resumedAt=Get-PCNow;$Project.timestamps.stoppedAt=''
  Write-PCLog $Project 'RESUMED' "actor=$Actor"
  Save-AI5Project $Project;$Project
}

function Stop-AI5ProjectEmergency($Project,[string]$Actor,[string]$Reason){
  if('control'-notin$Project.psobject.Properties.Name){$Project|Add-Member control ([pscustomobject]@{pauseRequested=$false;emergencyStopRequested=$false})}
  $Project.control.pauseRequested=$true;$Project.control.emergencyStopRequested=$true
  Set-AI5ProjectTimingStatus $Project 'STOPPED'|Out-Null
  $Project.autoExecution.mode='OFF';$Project.autoExecution.enabled=$false
  $Project.status='BLOCKED';$Project.blockedBy='TEPPEI';$Project.stopCode='EMERGENCY_STOP';$Project.stopReason=$(if($Reason){$Reason}else{'Emergency stop requested'});$Project.timestamps.stoppedAt=Get-PCNow
  # Preserve an active writer lock until the worker confirms a terminal task state.
  Write-PCLog $Project 'EMERGENCY_STOP' $Project.stopReason
  Save-AI5Project $Project;$Project
}

function Set-AI5ProjectInterrupt($Project,[string]$Actor,[string]$Text){
  $Project.priorityInterrupt=$true
  if($Text){$Project.nextAction=$Text}
  Write-PCLog $Project 'PRIORITY_INTERRUPT' $Text
  Save-AI5Project $Project;$Project
}

function Get-AI5RoomInstructionClass([string]$Text){
  if($Text-match'(?i)(緊急停止|emergency\s*stop|immediate(ly)?\s*stop|kill\s*now|全停止)'){return 'EMERGENCY_STOP'}
  if($Text-match'(?i)(一時停止|いったん止め|hold on|please\s*pause|^pause$|\bpause\b)'){return 'PAUSE'}
  if($Text-match'(?i)(優先|割り込み|urgent|interrupt|priority)'){return 'PRIORITY_INTERRUPT'}
  'NORMAL_ADD'
}

function Add-AI5RoomInstruction($Project,[string]$Text,[string]$Actor='TEPPEI'){
  if([string]::IsNullOrWhiteSpace($Text)){throw'instruction_required'}
  $class=Get-AI5RoomInstructionClass $Text
  $entry=[ordered]@{id=(Get-PCGuid);text=$Text;class=$class;actor=$Actor;at=Get-PCNow}
  $Project.room.instructions=@(@($Project.room.instructions)+,$entry)
  Add-PCHistory $Project 'ROOM_INSTRUCTION' $Actor "${class}: $Text"
  if(Test-PCApproval $Text){
    Set-AI5ProjectTimingStatus $Project 'STOPPED'|Out-Null
    $Project.phase='WAITING_FOR_APPROVAL';$Project.status='APPROVAL_REQUIRED';$Project.blockedBy='TEPPEI';$Project.stopCode='TEPPEI_WAITING'
    $Project.stopReason=$Text;$Project.timestamps.stoppedAt=Get-PCNow
    Write-PCLog $Project 'APPROVAL_STOP' $Text
    Save-AI5Project $Project
    return [ordered]@{project=$Project;instruction=$entry}
  }
  switch($class){
    'EMERGENCY_STOP'{$Project=Stop-AI5ProjectEmergency $Project $Actor $Text}
    'PAUSE'{$Project=Pause-AI5Project $Project $Actor}
    'PRIORITY_INTERRUPT'{$Project=Set-AI5ProjectInterrupt $Project $Actor $Text}
    default{if(!$Project.nextAction){$Project.nextAction=$Text};Save-AI5Project $Project}
  }
  [ordered]@{project=$Project;instruction=$entry}
}

function Set-AI5ProjectWriter($Project,[string]$NewWriter,[string]$Actor='TEPPEI'){
  if([string]::IsNullOrWhiteSpace($NewWriter)){throw'writer_required'}
  if($Project.writer-eq$NewWriter){return $Project}
  if($Project.execution.taskId){throw'writer_change_requires_safe_point'}
  $wasRunning=$Project.status-eq'RUNNING'
  if($wasRunning){$Project=Pause-AI5Project $Project $Actor}
  if($Project.execution.lockId){Exit-AI5ProjectLock $Project.projectId $Project.execution.lockId;$Project.execution.lockId=''}
  $oldWriter=$Project.writer
  $Project.writer=$NewWriter
  Add-PCHistory $Project 'WRITER_CHANGED' $Actor "$oldWriter -> $NewWriter"
  Save-AI5Project $Project
  if($wasRunning){$Project=Resume-AI5Project $Project $Actor}
  $Project
}

function Set-AI5ProjectReviewer($Project,[string]$NewReviewer,[string]$Actor='TEPPEI'){
  if([string]::IsNullOrWhiteSpace($NewReviewer)){throw'reviewer_required'}
  $old=$Project.reviewer;$Project.reviewer=$NewReviewer
  Add-PCHistory $Project 'REVIEWER_CHANGED' $Actor "$old -> $NewReviewer"
  Save-AI5Project $Project;$Project
}

function Request-AI5ManusAudit($Project,[string]$Actor='TEPPEI'){
  $Project.manusAudit.status='REQUESTED';$Project.manusAudit.requestedAt=Get-PCNow;$Project.manusAudit.completedAt='';$Project.manusAudit.summary=''
  Add-PCHistory $Project 'MANUS_AUDIT_REQUESTED' $Actor 'Manus audit requested'
  Save-AI5Project $Project;$Project
}

function Get-AI5ProjectRoom($Project){
  $timing=Get-AI5ProjectTiming $Project
  [ordered]@{
    projectId=$Project.projectId;name=$Project.name
    repository=[ordered]@{owner=$Project.repository.owner;name=$Project.repository.name;branch=$Project.repository.activeBranch;head=$Project.repository.latestCommit;worktree=$Project.repository.worktree;linkState=$Project.repository.linkState;sync=$Project.repository.sync}
    activeTaskId=$Project.execution.taskId;writer=$Project.writer;reviewer=$Project.reviewer;status=$Project.status;phase=$Project.phase;blockedBy=$Project.blockedBy;stopCode=$Project.stopCode
    currentTask=$Project.currentTask;nextAction=$Project.nextAction;stopReason=$Project.stopReason;priorityInterrupt=$Project.priorityInterrupt;progress=$(if($Project.progress){$Project.progress}else{0})
    timing=$timing;timestamps=$Project.timestamps;approvalCount=(Get-AI5ProjectApprovalCount $Project)
    manusAudit=$Project.manusAudit;instructions=@($Project.room.instructions);timeline=@($Project.history|Select-Object -Last 100)
  }
}

function Get-AI5ApprovalAggregate{
  $tasks=@()
  if(Get-Command Get-AI5Tasks -ErrorAction SilentlyContinue){$tasks=@(Get-AI5Tasks 500|Where-Object{$_.status-eq'waiting_approval'})}
  $groups=$tasks|Where-Object{$_.projectContext-and$_.projectContext.projectId}|Group-Object{$_.projectContext.projectId}
  $items=@()
  foreach($g in $groups){
    $projectIdValue=$g.Name;$project=if(Get-Command Get-AI5Project -ErrorAction SilentlyContinue){Get-AI5Project $projectIdValue}else{$null}
    $items+=,[ordered]@{projectId=$projectIdValue;projectName=$(if($project){$project.name}else{$projectIdValue});count=$g.Count;tasks=@($g.Group|ForEach-Object{[ordered]@{taskId=$_.taskId;objective=$_.objective;createdAt=$_.createdAt}})}
  }
  $known=@($items|ForEach-Object{$_.projectId})
  foreach($project in @(Get-AI5Projects|Where-Object{$_.status-eq'APPROVAL_REQUIRED'-and$_.projectId-notin$known})){
    $items+=,[ordered]@{projectId=$project.projectId;projectName=$project.name;count=1;tasks=@([ordered]@{taskId='';objective=$project.stopReason;createdAt=$project.timestamps.stoppedAt})}
  }
  $unassigned=@($tasks|Where-Object{!$_.projectContext-or!$_.projectContext.projectId})
  [ordered]@{totalWaiting=(@($items|ForEach-Object{$_.count}|Measure-Object -Sum).Sum+$unassigned.Count);byProject=$items;unassigned=@($unassigned|ForEach-Object{[ordered]@{taskId=$_.taskId;objective=$_.objective}})}
}
