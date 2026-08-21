function ConvertTo-AI5CommonState {
  param([string]$Status,[string]$Agent)
  switch($Status.ToLowerInvariant()){
    'queued'{'QUEUED'} 'received'{'QUEUED'} 'planning'{'THINKING'} 'routing'{'THINKING'}
    'running'{if($Agent-eq'gemini'){'RESEARCHING'}elseif($Agent-eq'claude'){'REVIEWING'}else{'RUNNING'}}
    'reviewing'{'REVIEWING'} 'validating'{'REVIEWING'} 'retrying'{'RUNNING'}
    'waiting_approval'{'WAITING_APPROVAL'} 'completed'{'COMPLETED'} 'failed'{'ERROR'}
    'cancelled'{'READY'} default{'READY'}
  }
}
function Get-AI5CommandCenter {
  $tasks=@(Get-AI5Tasks 100);$projects=@(Get-AI5Projects);$active=@($tasks|Where-Object{$_.status-notin@('completed','failed','cancelled')})
  $bridge=Get-AI5CodexHealth;$claude=Get-AI5ClaudeHealth;$gemini=Get-AI5SpecialistHealth 'gemini';$manus=Get-AI5ManusHealth;$notebook=Get-AI5NotebookLMHealth
  $health=@{zero=[ordered]@{available=$true;connection='local_policy';quota='not_applicable'};codex=[ordered]@{available=[bool]($script:MockMode-or$bridge.available);connection=$(if($script:MockMode){'mock'}elseif($bridge.available){'official_cli'}else{'not_connected'});quota='unknown'};claude=$claude;gemini=$gemini;manus=$manus;notebooklm=$notebook}
  $roles=@{zero='総司令塔';codex='PC施工';claude='設計監査';gemini='調査';manus='Web実務';notebooklm='知識庫（読取専用）'};$agents=[ordered]@{}
  foreach($id in @('zero','codex','claude','gemini','manus','notebooklm')){
    $task=$active|Where-Object{$_.assignedPrimary-eq$id-or$_.assignedSecondary-contains$id-or$_.requested_target-eq$id}|Select-Object -First 1
    $latest=$tasks|Where-Object{$_.assignedPrimary-eq$id-or$_.assignedSecondary-contains$id-or$_.requested_target-eq$id}|Select-Object -First 1
    $h=$health[$id];$state=if($task){ConvertTo-AI5CommonState $task.status $id}elseif(!$h.available){if($h.connection-eq'rate_limited'){'RATE_LIMITED'}else{'OFFLINE'}}elseif($latest-and$latest.status-eq'completed'){'COMPLETED'}else{'READY'}
    $projectId=if($task.projectContext){$task.projectContext.projectId}else{$null};$project=$projects|Where-Object{$_.projectId-eq$projectId}|Select-Object -First 1
    $agents[$id]=[ordered]@{id=$id;role=$roles[$id];state=$state;connection=$h.connection;quota=$h.quota;checkedAt=$h.checked_at;app=$h.app;web=$h.web;route=$h.route;taskId=$task.taskId;task=$task.objective;projectId=$projectId;project=$project.name;startedAt=$(if($task.bridge.startedAt){$task.bridge.startedAt}else{$task.createdAt});stage=$(if($task){$task.timeline[-1].label}else{'待機'});lastResult=$latest.result.summary;error=$(if($latest.status-eq'failed'){$latest.result.failureReason}else{$null});historicalError=[bool]($latest.status-eq'failed'-and!$task);progress=$(if($task){@($task.timeline).Count}else{0})}
  }
  $waiting=@($tasks|Where-Object{$_.status-eq'waiting_approval'});$flows=@($active|ForEach-Object{$current=$_;[ordered]@{taskId=$current.taskId;objective=$current.objective;projectId=$current.projectContext.projectId;requestedTarget=$current.requested_target;nodes=@('zero')+@($current.assignedPrimary)+@($current.assignedSecondary|Where-Object{$_-ne$current.assignedPrimary})+@('zero');status=$current.status}})
  $mobileHealth=Get-MobileHealth
  [ordered]@{generatedAt=[DateTime]::UtcNow.ToString('o');pc='ONLINE';machine=$mobileHealth.machine;components=$mobileHealth;bridge=$(if($bridge.available){'READY'}else{'OFFLINE'});tailscale=$mobileHealth.remote;approvalCount=$waiting.Count;agents=$agents;liveTasks=$active;recentResults=@($tasks|Where-Object{$_.status-in@('completed','failed')}|Select-Object -First 12);flows=$flows;writeLocks=@(Get-AI5ActiveLocks);notificationPolicy=[ordered]@{approvalSlots=@('10:00','12:00','15:00');afterHours='18:00';completion='silent_in_app';timeZone='Asia/Tokyo'}}
}
