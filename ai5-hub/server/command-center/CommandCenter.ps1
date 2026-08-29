function ConvertTo-AI5CommonState {
  param([string]$Status,[string]$Agent)
  switch(([string]$Status).ToLowerInvariant()){
    'queued'{'QUEUED'} 'received'{'QUEUED'} 'planning'{'THINKING'} 'routing'{'THINKING'}
    'running'{if($Agent-eq'gemini'){'RESEARCHING'}elseif($Agent-eq'claude'){'REVIEWING'}else{'RUNNING'}}
    'reviewing'{'REVIEWING'} 'validating'{'REVIEWING'} 'retrying'{'RETRY'}
    'waiting_approval'{'WAITING_APPROVAL'} 'blocked'{'BLOCKED'} 'completed'{'COMPLETED'} 'failed'{'ERROR'}
    'cancelled'{'READY'} default{'READY'}
  }
}

function Get-AI5OwnerTimestamp {
  param($Task,$Health)
  foreach($value in @($Task.updatedAt,$Task.updated_at,$Task.bridge.updatedAt,$Task.bridge.finishedAt,$Task.bridge.startedAt,$Task.createdAt,$Task.created_at,$Health.checked_at)){
    if($value){try{return [DateTimeOffset]::Parse([string]$value).ToUniversalTime()}catch{}}
  }
  $null
}

function Get-AI5OwnerFreshness {
  param($Timestamp,[bool]$Active)
  if(!$Timestamp){return [ordered]@{state='UNKNOWN';minutes=$null;label='更新時刻を確認できません'}}
  $minutes=[int][Math]::Max(0,[Math]::Floor(([DateTimeOffset]::UtcNow-$Timestamp).TotalMinutes));$limit=if($Active){15}else{1440}
  $label=if($minutes-lt1){'たった今'}elseif($minutes-lt60){"$minutes 分前"}elseif($minutes-lt1440){'{0} 時間前'-f[Math]::Floor($minutes/60)}else{'{0} 日前'-f[Math]::Floor($minutes/1440)}
  [ordered]@{state=$(if($minutes-le$limit){'FRESH'}else{'STALE'});minutes=$minutes;label=$label}
}

function Get-AI5OwnerProfitSummary {
  param([object[]]$Projects)
  $sales=@($Projects|Where-Object{$_.phase-in@('PUBLISHED','OPERATING','RELEASED')-or$_.status-eq'SELLING'})
  [ordered]@{verified=$false;reason='実決済データとの照合記録がないため未確認';todayNetProfit=$null;monthNetProfit=$null;monthTarget=$null;remainingToHundredMillion=$null;purchaseCount=$null;grossSales=$null;sellingProducts=@($sales|ForEach-Object{$_.name});bestSeller=$null}
}

function Get-AI5CommandCenter {
  $tasks=@(Get-AI5Tasks 100);$projects=@(Get-AI5Projects);$active=@($tasks|Where-Object{$_.status-notin@('completed','failed','cancelled')})
  $bridge=Get-AI5CodexHealth;$claude=Get-AI5ClaudeHealth;$gemini=Get-AI5SpecialistHealth 'gemini';$manus=Get-AI5ManusHealth;$notebook=Get-AI5NotebookLMHealth
  $now=[DateTimeOffset]::UtcNow.ToString('o')
  $health=@{zero=[ordered]@{available=$true;connection='local_policy';quota='not_applicable';checked_at=$now};codex=[ordered]@{available=[bool]($script:MockMode-or$bridge.available);connection=$(if($script:MockMode){'mock'}elseif($bridge.available){'official_cli'}else{'not_connected'});quota='unknown';checked_at=$now};claude=$claude;gemini=$gemini;manus=$manus;notebooklm=$notebook}
  $roles=@{zero='統括・判断・利益優先順位・作業振り分け';codex='実装・修正・テスト・PC施工・GitHub';claude='品質監査・反証・安全・クレーム防止';gemini='市場・競合・価格・国・候補調査';manus='購入者視点・販売ページ・Web実査・最終販売監査';notebooklm='過去資料・仕様・根拠の読み取り専用検索'};$agents=[ordered]@{}
  foreach($id in @('zero','codex','claude','gemini','manus','notebooklm')){
    $task=$active|Where-Object{$_.assignedPrimary-eq$id-or$_.assignedSecondary-contains$id-or$_.requested_target-eq$id}|Select-Object -First 1
    $latest=$tasks|Where-Object{$_.assignedPrimary-eq$id-or$_.assignedSecondary-contains$id-or$_.requested_target-eq$id}|Select-Object -First 1
    $h=$health[$id];$timestamp=Get-AI5OwnerTimestamp $task $h;$freshness=Get-AI5OwnerFreshness $timestamp ([bool]$task)
    $state=if($task){ConvertTo-AI5CommonState $task.status $id}elseif(!$h.available){if($h.connection-eq'rate_limited'){'RATE_LIMITED'}elseif($h.connection-eq'not_connected'){'UNCONNECTED'}else{'OFFLINE'}}elseif($latest-and$latest.status-eq'completed'){'COMPLETED'}else{'READY'}
    if($task-and$freshness.state-eq'STALE'){$state='STALE'}
    $projectId=if($task.projectContext){$task.projectContext.projectId}elseif($task.project_id){$task.project_id}else{$null};$project=$projects|Where-Object{$_.projectId-eq$projectId}|Select-Object -First 1
    $latestResult=if($latest.result.summary){$latest.result.summary}elseif($latest.result.result){$latest.result.result}else{$null}
    $nextAction=if($task.nextAction){$task.nextAction}elseif($project.nextAction){$project.nextAction}elseif($latest.result.nextAction){$latest.result.nextAction}else{'次の作業は未設定'}
    $blockReason=if($task.status-in@('blocked','failed')){if($task.result.failureReason){$task.result.failureReason}elseif($task.result.blockers){@($task.result.blockers)-join'、'}else{$task.errorType}}elseif(!$h.available){'正式な実行経路へ接続できていません'}else{$null}
    $agents[$id]=[ordered]@{id=$id;role=$roles[$id];state=$state;connection=$h.connection;available=[bool]$h.available;quota=$h.quota;checkedAt=$h.checked_at;app=$h.app;web=$h.web;route=$h.route;taskId=$task.taskId;task=$task.objective;currentAction=$(if($task){$task.timeline[-1].label}else{'待機中'});projectId=$projectId;project=$(if($project){$project.name}elseif($projectId){$projectId}else{$null});repository=$task.projectContext.repository;branch=$task.projectContext.branch;worktree=$(if($task.worktree_preflight.trusted){'READY'}elseif($task.projectContext.worktreePath){'REGISTERED'}else{'UNVERIFIED'});startedAt=$(if($task.bridge.startedAt){$task.bridge.startedAt}elseif($task.createdAt){$task.createdAt}else{$task.created_at});lastUpdate=$(if($timestamp){$timestamp.ToString('o')}else{$null});freshness=$freshness;stage=$(if($task){$task.timeline[-1].label}else{'待機'});latestResult=$latestResult;nextAction=$nextAction;blockReason=$blockReason;error=$(if($latest.status-eq'failed'){$latest.result.failureReason}else{$null});historicalError=[bool]($latest.status-eq'failed'-and!$task);progress=$(if($task){@($task.timeline).Count}else{0});approvalRequired=[bool]($task.status-eq'waiting_approval')}
  }
  $waiting=@($tasks|Where-Object{$_.status-eq'waiting_approval'});$flows=@($active|ForEach-Object{$current=$_;[ordered]@{taskId=$current.taskId;objective=$current.objective;projectId=$(if($current.projectContext){$current.projectContext.projectId}else{$current.project_id});requestedTarget=$current.requested_target;nodes=@('zero')+@($current.assignedPrimary)+@($current.assignedSecondary|Where-Object{$_-ne$current.assignedPrimary})+@('zero');status=$current.status;startedAt=$(if($current.bridge.startedAt){$current.bridge.startedAt}else{$current.createdAt});nextAction=$current.nextAction}})
  $mobileHealth=Get-MobileHealth
  [ordered]@{generatedAt=[DateTime]::UtcNow.ToString('o');pc='ONLINE';machine=$mobileHealth.machine;components=$mobileHealth;bridge=$(if($bridge.available){'READY'}else{'OFFLINE'});tailscale=$mobileHealth.remote;approvalCount=$waiting.Count;agents=$agents;liveTasks=$active;currentWork=$flows;ownerApprovals=$waiting;recentResults=@($tasks|Where-Object{$_.status-in@('completed','failed')}|Select-Object -First 12);profit=(Get-AI5OwnerProfitSummary $projects);flows=$flows;writeLocks=@(Get-AI5ActiveLocks);notificationPolicy=[ordered]@{approvalSlots=@('10:00','12:00','15:00');afterHours='18:00';completion='silent_in_app';timeZone='Asia/Tokyo'}}
}
