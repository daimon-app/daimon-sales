$ErrorActionPreference='Stop'
function Assert-Room($ok,[string]$message){if(!$ok){throw $message}}
$roomTestRoot=$(if($PSScriptRoot){$PSScriptRoot}else{$global:AI5TestRoot})
$appRoot=Split-Path (Split-Path $roomTestRoot)
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'server\storage\Store.ps1'))))
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'server\project-control\ProjectControl.ps1'))))
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'server\project-control\ProjectRoom.ps1'))))

$temp=Join-Path ([IO.Path]::GetTempPath()) ('ai5-room-'+[guid]::NewGuid().ToString('N'));$server=Join-Path $temp 'server';$app=Join-Path $temp 'app'
function New-TestRepo([string]$Path,[string]$Branch){
  New-Item -ItemType Directory -Force $Path | Out-Null
  & git -C $Path init -q 2>$null
  & git -C $Path checkout -q -b $Branch 2>$null
  & git -C $Path config user.email 'test@example.com' 2>$null
  & git -C $Path config user.name 'Test' 2>$null
  'seed' | Set-Content -LiteralPath (Join-Path $Path 'seed.txt') -Encoding UTF8
  & git -C $Path add -A 2>$null
  & git -C $Path commit -q -m init 2>$null
}
try{
  New-Item -ItemType Directory -Force (Join-Path $app 'project-control\projects') | Out-Null
  Copy-Item (Join-Path $appRoot 'project-control\registry.json') (Join-Path $app 'project-control\registry.json')
  Copy-Item (Join-Path $appRoot 'project-control\projects\*.json') (Join-Path $app 'project-control\projects')
  Initialize-AI5Store $server
  Initialize-AI5ProjectControl $server $app

  # --- list / room fields + isolation ---
  $repoA=Join-Path $temp 'repo-a';New-TestRepo $repoA 'feat/a'
  $repoB=Join-Path $temp 'repo-b';New-TestRepo $repoB 'feat/b'
  $a=New-AI5Project ([pscustomobject]@{projectId='room-a';name='Room A';repository='room-a'})
  $a.repository.worktree=$repoA;$a.repository.activeBranch='feat/a';$a.repository.linkState='LINKED';Save-AI5Project $a
  $b=New-AI5Project ([pscustomobject]@{projectId='room-b';name='Room B';repository='room-b'})
  $b.repository.worktree=$repoB;$b.repository.activeBranch='feat/b';$b.repository.linkState='LINKED';Save-AI5Project $b

  Add-AI5RoomInstruction $a 'カードのCSSを整える' 'TEPPEI' | Out-Null
  $a=Get-AI5Project 'room-a';$b=Get-AI5Project 'room-b'
  $roomA=Get-AI5ProjectRoom $a; $roomB=Get-AI5ProjectRoom $b
  foreach($key in @('projectId','writer','reviewer','status','activeTaskId')){Assert-Room ($roomA.Contains($key)) "room missing key $key"}
  Assert-Room ($roomA.repository.branch-eq'feat/a'-and$roomA.repository.worktree-eq$repoA) 'room repo/branch/worktree binding failed'
  Assert-Room ($roomA.writer-eq'CODEX'-and$roomA.reviewer-eq'CLAUDE') 'default writer/reviewer failed'
  Assert-Room (@($roomA.instructions).Count-eq1) 'room-a instruction not persisted'
  Assert-Room (@($roomB.instructions).Count-eq0) 'ROOM ISOLATION failed: room-b saw room-a instruction'
  Assert-Room (($roomB.timeline|Where-Object{$_.detail-match'CSS'}).Count-eq0) 'ROOM ISOLATION failed: room-b timeline leaked room-a content'

  # --- instruction classification ---
  Assert-Room ((Get-AI5RoomInstructionClass 'カードのCSSを整える')-eq'NORMAL_ADD') 'NORMAL_ADD classification failed'
  Assert-Room ((Get-AI5RoomInstructionClass '優先で割り込み対応して')-eq'PRIORITY_INTERRUPT') 'PRIORITY_INTERRUPT classification failed'
  Assert-Room ((Get-AI5RoomInstructionClass '一時停止してください')-eq'PAUSE') 'PAUSE classification failed'
  Assert-Room ((Get-AI5RoomInstructionClass '緊急停止して')-eq'EMERGENCY_STOP') 'EMERGENCY_STOP classification failed'

  # --- status / timeline via instructions ---
  $c=New-AI5Project ([pscustomobject]@{projectId='room-c';name='Room C';repository=''})
  $c.status='READY';Save-AI5Project $c
  $r=Add-AI5RoomInstruction $c 'ログイン画面の文言を直す' 'TEPPEI';$c=$r.project
  Assert-Room ($c.nextAction-eq'ログイン画面の文言を直す') 'NORMAL_ADD nextAction queueing failed'
  $r=Add-AI5RoomInstruction $c '優先で割り込み：設定画面を先にやって' 'TEPPEI';$c=$r.project
  Assert-Room ($c.priorityInterrupt-and$c.nextAction-match'設定画面') 'PRIORITY_INTERRUPT effect failed'
  $r=Add-AI5RoomInstruction $c '一時停止して' 'TEPPEI';$c=$r.project
  Assert-Room ($c.status-eq'PAUSED'-and$c.timing.status-eq'PAUSED') 'PAUSE instruction effect failed'
  $c=Resume-AI5Project $c 'TEPPEI'
  Assert-Room ($c.status-ne'PAUSED'-and$c.timing.status-eq'RUNNING') 'resume after pause instruction failed'
  $r=Add-AI5RoomInstruction $c '緊急停止：全部止めて' 'TEPPEI';$c=$r.project
  Assert-Room ($c.status-eq'BLOCKED'-and$c.stopCode-eq'EMERGENCY_STOP'-and$c.autoExecution.mode-eq'OFF') 'EMERGENCY_STOP effect failed'
  Assert-Room (@($c.room.instructions).Count-eq4) 'room instruction persistence count failed'
  Assert-Room (@($c.history|Where-Object{$_.type-eq'ROOM_INSTRUCTION'}).Count-eq4) 'room instruction timeline persistence failed'

  # --- timing accumulation + restart persistence ---
  $d=New-AI5Project ([pscustomobject]@{projectId='room-d';name='Room D';repository=''})
  Set-AI5ProjectTimingStatus $d 'RUNNING' | Out-Null
  $d.timing.runStartedAt=[DateTimeOffset]::Now.AddSeconds(-5).ToString('o')
  $live=Get-AI5ProjectTiming $d
  Assert-Room ($live.accumulatedRunningSeconds-ge 4.5) 'live running elapsed calc failed'
  Set-AI5ProjectTimingStatus $d 'PAUSED' | Out-Null
  Assert-Room ($d.timing.accumulatedRunningSeconds-ge 4.5) 'accumulatedRunningSeconds not persisted on pause'
  Save-AI5Project $d
  $dReloaded=Get-AI5Project 'room-d'
  Assert-Room ($dReloaded.timing.accumulatedRunningSeconds-ge 4.5-and$dReloaded.timing.status-eq'PAUSED') 'RESTART persistence of timing failed'

  # --- pause/resume revalidation + lock rejection ---
  $e=New-AI5Project ([pscustomobject]@{projectId='room-e';name='Room E';repository='room-e'})
  $repoE=Join-Path $temp 'repo-e';New-TestRepo $repoE 'feat/e'
  $e.repository.worktree=$repoE;$e.repository.activeBranch='feat/e';$e.repository.linkState='LINKED'
  $e.status='RUNNING';$e.execution.taskId='task_room_e';$e.execution.lockId='task_room_e'
  Save-AI5Task ([pscustomobject]@{taskId='task_room_e';status='running';updatedAt=''})
  $lock=Enter-AI5ProjectLock 'room-e' 'CODEX' 'task_room_e';Save-AI5Project $e
  $e=Pause-AI5Project $e 'TEPPEI'
  Assert-Room ($e.status-eq'PAUSED') 'valid pause revalidation rejected unexpectedly'
  $e=Resume-AI5Project $e 'TEPPEI'
  Assert-Room ($e.status-eq'RUNNING') 'valid resume revalidation rejected unexpectedly'

  Exit-AI5ProjectLock 'room-e' 'task_room_e'
  $e=Get-AI5Project 'room-e'
  $rejected=$false
  try{Pause-AI5Project $e 'TEPPEI' | Out-Null}catch{$rejected=$_.Exception.Message-match'lock_missing'}
  Assert-Room $rejected 'LOCK REJECTION (missing lock) did not throw'

  $e=Get-AI5Project 'room-e';$e.execution.lockId='task_room_e';$e.repository.activeBranch='nonexistent-branch';Save-AI5Project $e
  $rejected=$false
  try{Pause-AI5Project $e 'TEPPEI' | Out-Null}catch{$rejected=$_.Exception.Message-match'branch_mismatch'}
  Assert-Room $rejected 'branch mismatch revalidation did not reject pause'

  $e=Get-AI5Project 'room-e';$e.repository.activeBranch='feat/e';$e.repository.worktree=(Join-Path $temp 'missing-worktree');Save-AI5Project $e
  $rejected=$false
  try{Pause-AI5Project $e 'TEPPEI' | Out-Null}catch{$rejected=$_.Exception.Message-match'worktree_missing'}
  Assert-Room $rejected 'worktree missing revalidation did not reject pause'
  Exit-AI5ProjectLock 'room-e' 'task_room_e'

  # --- writer handoff only at a safe point ---
  $f=New-AI5Project ([pscustomobject]@{projectId='room-f';name='Room F';repository='room-f'})
  $repoF=Join-Path $temp 'repo-f';New-TestRepo $repoF 'feat/f'
  $f.repository.worktree=$repoF;$f.repository.activeBranch='feat/f';$f.repository.linkState='LINKED'
  $f.status='RUNNING';$f.execution.taskId='task_room_f';$f.execution.lockId='task_room_f'
  Save-AI5Task ([pscustomobject]@{taskId='task_room_f';status='running';updatedAt=''})
  Enter-AI5ProjectLock 'room-f' 'CODEX' 'task_room_f' | Out-Null;Save-AI5Project $f
  $rejected=$false
  try{Set-AI5ProjectWriter $f 'CLAUDE' 'TEPPEI'|Out-Null}catch{$rejected=$_.Exception.Message-match'writer_change_requires_safe_point'}
  Assert-Room $rejected 'active writer handoff was not rejected'
  Exit-AI5ProjectLock 'room-f' 'task_room_f';$f.execution.taskId='';$f.execution.lockId='';$f.status='WAITING';Save-AI5Project $f
  $f=Set-AI5ProjectWriter $f 'CLAUDE' 'TEPPEI'
  Assert-Room ($f.writer-eq'CLAUDE') 'safe-point writer handoff failed'
  Assert-Room (@($f.history|Where-Object{$_.type-eq'WRITER_CHANGED'}).Count-eq1) 'writer change not recorded in timeline'
  $f=Set-AI5ProjectReviewer $f 'GEMINI' 'TEPPEI'
  Assert-Room ($f.reviewer-eq'GEMINI') 'reviewer change failed'

  # active task always blocks writer changes even if lock ownership is foreign
  $f2=New-AI5Project ([pscustomobject]@{projectId='room-f2';name='Room F2';repository=''})
  $f2.status='WAITING';$f2.execution.taskId='task_room_f2';$f2.execution.lockId=''
  Save-AI5Task ([pscustomobject]@{taskId='task_room_f2';status='queued';updatedAt=''})
  Save-AI5Task ([pscustomobject]@{taskId='other-task';status='running';updatedAt=''})
  $foreignLockPath=Join-Path (Join-Path $server 'runtime\project-locks') 'room-f2.lock'
  Write-PCJson @{projectId='room-f2';lockOwner='SOMEONE_ELSE';lockedAt=Get-PCNow;expiresAt=[DateTimeOffset]::Now.AddMinutes(30).ToString('o');taskId='other-task'} $foreignLockPath
  Save-AI5Project $f2
  $rejected=$false
  try{Set-AI5ProjectWriter $f2 'CLAUDE' 'TEPPEI' | Out-Null}catch{$rejected=$_.Exception.Message-match'writer_change_requires_safe_point'}
  Assert-Room $rejected 'writer handoff safe-point rejection failed'
  Remove-Item -Force $foreignLockPath -ErrorAction SilentlyContinue

  # --- approval routing/aggregation ---
  Save-AI5Task ([pscustomobject]@{taskId='appr-1';status='waiting_approval';objective='A作業1';createdAt=Get-PCNow;updatedAt='';projectContext=[pscustomobject]@{projectId='room-a'}})
  Save-AI5Task ([pscustomobject]@{taskId='appr-2';status='waiting_approval';objective='A作業2';createdAt=Get-PCNow;updatedAt='';projectContext=[pscustomobject]@{projectId='room-a'}})
  Save-AI5Task ([pscustomobject]@{taskId='appr-3';status='waiting_approval';objective='B作業1';createdAt=Get-PCNow;updatedAt='';projectContext=[pscustomobject]@{projectId='room-b'}})
  Save-AI5Task ([pscustomobject]@{taskId='appr-4';status='waiting_approval';objective='チャット直接依頼';createdAt=Get-PCNow;updatedAt=''})
  $h=New-AI5Project ([pscustomobject]@{projectId='room-h';name='Room H';repository=''})
  $h=(Add-AI5RoomInstruction $h '本番公開を開始して' 'TEPPEI').project
  Assert-Room ($h.status-eq'APPROVAL_REQUIRED'-and$h.blockedBy-eq'TEPPEI'-and$h.stopCode-eq'TEPPEI_WAITING') 'room approval gate failed'
  $agg=Get-AI5ApprovalAggregate
  $groupA=@($agg.byProject|Where-Object{$_.projectId-eq'room-a'})[0]
  $groupB=@($agg.byProject|Where-Object{$_.projectId-eq'room-b'})[0]
  Assert-Room ($groupA.count-eq2-and$groupB.count-eq1) 'approval aggregation by project failed'
  Assert-Room (@($agg.unassigned).Count-eq1) 'unassigned approval routing failed'
  Assert-Room ($agg.totalWaiting-eq5-and@($agg.byProject|Where-Object{$_.projectId-eq'room-h'}).Count-eq1) 'total/project-state waiting approval count failed'
  Assert-Room ((Get-AI5ProjectApprovalCount (Get-AI5Project 'room-a'))-eq2) 'per-project approval count failed'

  # --- 100 projects ---
  for($i=1;$i-le100;$i++){New-AI5Project ([pscustomobject]@{projectId=("room-bulk-{0:d3}" -f $i);name="Room Bulk $i";repository=''}) | Out-Null}
  $all=@(Get-AI5Projects)
  Assert-Room ($all.Count-ge106) '100 project room scale count failed'
  foreach($p in $all){Get-AI5ProjectRoom $p | Out-Null}
  $summary=Get-AI5ProjectSummary
  Assert-Room (@($summary.projects|Where-Object{$_.psobject.Properties.Name-contains'timingView'}).Count-eq$all.Count) 'summary timingView augmentation missing at scale'
  Assert-Room (@($summary.projects|Where-Object{$_.psobject.Properties.Name-contains'approvalCount'}).Count-eq$all.Count) 'summary approvalCount augmentation missing at scale'

  # --- regression: Single Writer / AUTO defaults untouched by new fields ---
  $g=New-AI5Project ([pscustomobject]@{projectId='room-g';name='Room G';repository=''})
  Assert-Room (!$g.autoExecution.enabled-and$g.autoExecution.mode-eq'OFF') 'AUTO default regression failed'
  $lockG=Enter-AI5ProjectLock 'room-g' 'CODEX' 'gtask-1'
  $blocked=$false
  try{Enter-AI5ProjectLock 'room-g' 'CODEX' 'gtask-2' | Out-Null}catch{$blocked=$true}
  Assert-Room $blocked 'Single Writer regression failed'
  Exit-AI5ProjectLock 'room-g' 'gtask-1'

  'PROJECT_ROOM_TESTS_OK'
}finally{if(Test-Path $temp){Remove-Item -Recurse -Force $temp}}
