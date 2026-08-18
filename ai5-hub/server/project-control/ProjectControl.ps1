function Initialize-AI5ProjectControl {
  param([string]$ServerRoot,[string]$AppRoot)
  $script:PCSourceRoot=Join-Path $AppRoot 'project-control';$script:PCWorkspaceRoot=Split-Path $AppRoot;$script:PCRoot=Join-Path $ServerRoot 'data\project-control';$script:PCProjects=Join-Path $script:PCRoot 'projects';$script:PCLocks=Join-Path $ServerRoot 'runtime\project-locks'
  @($script:PCRoot,$script:PCProjects,$script:PCLocks)|ForEach-Object{New-Item -ItemType Directory -Force $_|Out-Null}
  if(!(Test-Path (Join-Path $script:PCRoot 'registry.json'))){Copy-Item (Join-Path $script:PCSourceRoot 'registry.json') (Join-Path $script:PCRoot 'registry.json')}
  Get-ChildItem (Join-Path $script:PCSourceRoot 'projects') -Filter '*.json'|ForEach-Object{$to=Join-Path $script:PCProjects $_.Name;if(!(Test-Path $to)){Copy-Item $_.FullName $to}}
}
function Get-PCNow{[DateTimeOffset]::Now.ToString('o')}
function Get-PCSafeId([string]$Id){if($Id-notmatch'^[a-z0-9][a-z0-9._-]{1,79}$'){throw'invalid_project_id'};$Id}
function Get-PCPath([string]$Id){Join-Path $script:PCProjects ((Get-PCSafeId $Id)+'.json')}
function Read-PCJson([string]$Path){Get-Content -Raw -Encoding UTF8 -LiteralPath $Path|ConvertFrom-Json}
function Write-PCJson($Value,[string]$Path){$tmp="$Path.tmp";$Value|ConvertTo-Json -Depth 20|Set-Content -Encoding UTF8 -LiteralPath $tmp;Move-Item -Force -LiteralPath $tmp -Destination $Path}
function Get-AI5Project([string]$Id){$p=Get-PCPath $Id;if(Test-Path $p){Read-PCJson $p}}
function Get-AI5Projects{$registry=Read-PCJson (Join-Path $script:PCRoot 'registry.json');@($registry.projects|ForEach-Object{Get-AI5Project $_}|Where-Object{$_})}
function Add-PCHistory($Project,[string]$Type,[string]$Actor,[string]$Detail){$Project.history+=,@{at=Get-PCNow;type=$Type;actor=$Actor;detail=$Detail}}
function Save-AI5Project($Project){$Project.timestamps.updatedAt=Get-PCNow;Write-PCJson $Project (Get-PCPath $Project.projectId)}
function Get-AI5ProjectSummary{
  $all=@(Get-AI5Projects);$count=@{};foreach($key in @('running','aiRunning','stopped','human','error','release','selling','completed','autoOn','autoOff')){$count[$key]=0}
  foreach($p in $all){if($p.status-eq'RUNNING'){$count.running++};if(@($p.aiState.psobject.Properties.Value)-contains'RUNNING'){$count.aiRunning++};if($p.status-in@('WAITING','BLOCKED','PAUSED')){$count.stopped++};if($p.blockedBy-eq'TEPPEI'){$count.human++};if($p.status-eq'FAILED'-or$p.stopCode-in@('ERROR_LOOP_STOP','CREDIT_PROTECTION_STOP')){$count.error++};if($p.phase-eq'RELEASE_READY'){$count.release++};if($p.phase-in@('PUBLISHED','OPERATING')){$count.selling++};if($p.status-eq'COMPLETED'){$count.completed++};if($p.autoExecution.enabled){$count.autoOn++}else{$count.autoOff++}}
  @{projects=$all;counts=$count;generatedAt=Get-PCNow;timezone='Asia/Tokyo'}
}
function New-AI5Project($Body){
  $id=Get-PCSafeId $Body.projectId;if(Test-Path (Get-PCPath $id)){throw'project_exists'};$now=Get-PCNow;$repoName=[string]$Body.repository
  $p=[ordered]@{schemaVersion=1;projectId=$id;name=[string]$Body.name;repository=[ordered]@{owner='';name=$repoName;defaultBranch='main';activeBranch='';latestCommit='';linkState=$(if($repoName){'LINKED'}else{'UNLINKED'})};phase='IDEA';status='NOT_STARTED';blockedBy='NONE';stopCode='NONE';autoExecution=@{enabled=$false};executionPolicy=@{risk='LOW';costClass='NORMAL';maxRetry=2;dailyAutoRuns=3;requireApprovalAbove='HIGH';retryCount=0;runsToday=0;failureFingerprint='';consecutiveFailures=0};timestamps=@{createdAt=$now;updatedAt=$now;stoppedAt='';resumedAt='';workStartedAt='';workCompletedAt='';lastGitHubSyncAt='';lastZeroActionAt='';lastCodexActionAt='';lastClaudeActionAt='';lastGeminiActionAt='';lastManusActionAt='';lastTeppeiActionAt='';publishedAt='';lastMaintenanceAt='';heartbeatAt=''};currentTask='';lastCompletedTask='';nextAction='';stopReason='';aiState=@{zero='IDLE';codex='IDLE';claude='NOT_REQUIRED';gemini='NOT_REQUIRED';manus='NOT_REQUIRED';notebooklm='NOT_REQUIRED'};qualityGate=@{tests='UNKNOWN';review='UNKNOWN';fieldValidation='UNKNOWN';release='UNKNOWN'};versions=@();history=@()}
  Add-PCHistory $p 'PROJECT_REGISTERED' 'TEPPEI' 'PROJECTS UIから登録';Save-AI5Project $p;$r=Read-PCJson (Join-Path $script:PCRoot 'registry.json');$r.projects+=,$id;$r.updatedAt=$now;Write-PCJson $r (Join-Path $script:PCRoot 'registry.json');$p
}
function Test-PCApproval([string]$Text){$Text-match'(?i)(課金|購入|契約|本番公開|販売開始|public repository|oauth|2fa|captcha|password|秘密|merge|force push|履歴破壊|大量削除|不可逆|法的同意)'}
function Set-AI5ProjectState($Project,$Body,[string]$Actor='ZERO'){
  $oldPhase=$Project.phase;$oldStatus=$Project.status;$now=Get-PCNow
  foreach($key in @('phase','status','blockedBy','stopCode','currentTask','lastCompletedTask','nextAction','stopReason')){if($null-ne$Body.$key){$Project.$key=$Body.$key}}
  if($Project.status-in@('WAITING','BLOCKED','FAILED','APPROVAL_REQUIRED','PAUSED')-and!$Project.timestamps.stoppedAt){$Project.timestamps.stoppedAt=$now}
  if($oldStatus-in@('WAITING','BLOCKED','FAILED','APPROVAL_REQUIRED','PAUSED')-and$Project.status-in@('READY','RUNNING','OPERATING')){$Project.timestamps.resumedAt=$now;$Project.timestamps.stoppedAt=''}
  if($Project.status-eq'RUNNING'-and$oldStatus-ne'RUNNING'){$Project.timestamps.workStartedAt=$now}
  if($Project.status-in@('COMPLETED','PUBLISHED','OPERATING')-and$oldStatus-eq'RUNNING'){$Project.timestamps.workCompletedAt=$now}
  if($Project.phase-eq'PUBLISHED'-and!$Project.timestamps.publishedAt){$Project.timestamps.publishedAt=$now;$Project.versions+=,@{publishedAt=$now;commit=$Project.repository.latestCommit}}
  if(Test-PCApproval (($Project.currentTask+' '+$Project.nextAction))){$Project.phase='WAITING_FOR_APPROVAL';$Project.status='APPROVAL_REQUIRED';$Project.blockedBy='TEPPEI';$Project.stopCode='TEPPEI_WAITING';$Project.timestamps.stoppedAt=$now}
  Add-PCHistory $Project 'STATE_CHANGED' $Actor "$oldPhase/$oldStatus → $($Project.phase)/$($Project.status)";Save-AI5Project $Project;$Project
}
function Set-AI5ProjectAuto($Project,[bool]$Enabled,[string]$Actor='TEPPEI'){$Project.autoExecution.enabled=$Enabled;Add-PCHistory $Project 'AUTO_EXECUTION_CHANGED' $Actor $(if($Enabled){'ON'}else{'OFF'});Save-AI5Project $Project;$Project}
function Test-AI5ProjectExecution($Project){
  if(!$Project.autoExecution.enabled){return @{allowed=$false;reason='AUTO_OFF'}}
  if($Project.status-eq'APPROVAL_REQUIRED'-or$Project.blockedBy-eq'TEPPEI'-or(Test-PCApproval ($Project.currentTask+' '+$Project.nextAction))){return @{allowed=$false;reason='TEPPEI_APPROVAL_REQUIRED'}}
  if($Project.executionPolicy.costClass-in@('HIGH','VERY_HIGH')-or$Project.executionPolicy.risk-in@('HIGH','VERY_HIGH')){return @{allowed=$false;reason='CREDIT_PROTECTION_STOP'}}
  if($Project.executionPolicy.consecutiveFailures-ge2-or$Project.executionPolicy.retryCount-ge$Project.executionPolicy.maxRetry){return @{allowed=$false;reason='ERROR_LOOP_STOP'}}
  if($Project.executionPolicy.runsToday-ge$Project.executionPolicy.dailyAutoRuns){return @{allowed=$false;reason='CREDIT_PROTECTION_STOP'}}
  @{allowed=$true;reason='READY'}
}
function Update-AI5ProjectStopCode($Project){
  $states=@($Project.aiState.psobject.Properties.Value);$done=@($states|Where-Object{$_-notin@('DONE','PASSED','NOT_REQUIRED')}).Count-eq0
  if($done-and$Project.nextAction-and$Project.status-notin@('RUNNING','PUBLISHED','OPERATING','ARCHIVED')){$Project.stopCode='ALL_AI_DONE_BUT_IDLE';$Project.status='WAITING';$Project.blockedBy='ZERO';if(!$Project.timestamps.stoppedAt){$Project.timestamps.stoppedAt=Get-PCNow};$Project.stopReason='必須AI工程とGitHub同期は完了したが、次工程が未投入'}
  elseif($Project.blockedBy-eq'ZERO'){$Project.stopCode='ZERO_STOPPED'}elseif($Project.blockedBy-eq'CODEX'){$Project.stopCode='CODEX_STOPPED'}elseif($Project.blockedBy-eq'CLAUDE'){$Project.stopCode='CLAUDE_STOPPED'}elseif($Project.blockedBy-eq'GEMINI'){$Project.stopCode='GEMINI_STOPPED'}elseif($Project.blockedBy-eq'MANUS'){$Project.stopCode='MANUS_STOPPED'}elseif($Project.blockedBy-eq'TEPPEI'){$Project.stopCode='TEPPEI_WAITING'}
  Save-AI5Project $Project;$Project
}
function Sync-AI5ProjectGit($Project){
  if($Project.repository.linkState-ne'LINKED'){return $Project};$root=$script:PCWorkspaceRoot
  $branch=(& git -C $root branch --show-current 2>$null)-join'';$head=(& git -C $root rev-parse HEAD 2>$null)-join''
  if(!$head){$Project.blockedBy='GITHUB';$Project.stopCode='GITHUB_SYNC_WAIT';$Project.status='BLOCKED';$Project.stopReason='Git repository state unavailable'}else{$expected=$Project.repository.latestCommit;$Project.repository.activeBranch=$branch;$Project.repository.latestCommit=$head;$Project.timestamps.lastGitHubSyncAt=Get-PCNow;if($expected-and$expected-ne$head){Add-PCHistory $Project 'GITHUB_SYNCED' 'SYSTEM' "$expected → $head"};if($Project.blockedBy-eq'GITHUB'){$Project.blockedBy='NONE';$Project.stopCode='NONE';$Project.stopReason=''}}
  Save-AI5Project $Project;$Project
}
function Invoke-AI5ProjectScan{$results=@();foreach($p in Get-AI5Projects){$p=Sync-AI5ProjectGit $p;$p=Update-AI5ProjectStopCode $p;$results+=,@{projectId=$p.projectId;execution=Test-AI5ProjectExecution $p;stopCode=$p.stopCode}};@{scannedAt=Get-PCNow;projects=$results;autoDispatch=$false}}
function Enter-AI5ProjectLock([string]$ProjectId,[string]$Owner,[string]$TaskId,[int]$Minutes=30){$path=Join-Path $script:PCLocks ((Get-PCSafeId $ProjectId)+'.lock');if(Test-Path $path){$old=Read-PCJson $path;if([DateTimeOffset]::Parse($old.expiresAt)-gt[DateTimeOffset]::Now){throw'project_locked'};Remove-Item -Force $path};$value=@{projectId=$ProjectId;lockOwner=$Owner;lockedAt=Get-PCNow;expiresAt=[DateTimeOffset]::Now.AddMinutes($Minutes).ToString('o');taskId=$TaskId};Write-PCJson $value $path;$value}
function Exit-AI5ProjectLock([string]$ProjectId,[string]$TaskId){$path=Join-Path $script:PCLocks ((Get-PCSafeId $ProjectId)+'.lock');if(Test-Path $path){$lock=Read-PCJson $path;if($lock.taskId-eq$TaskId){Remove-Item -Force $path}}}
function Invoke-AI5ProjectRecovery([int]$Minutes=30){foreach($p in Get-AI5Projects){if($p.status-eq'RUNNING'-and$p.timestamps.heartbeatAt-and[DateTimeOffset]::Parse($p.timestamps.heartbeatAt)-lt[DateTimeOffset]::Now.AddMinutes(-$Minutes)){$p.status='BLOCKED';$p.blockedBy='SYSTEM';$p.stopCode='SYSTEM';$p.stopReason='heartbeat timeout; duplicate execution prevented';$p.timestamps.stoppedAt=Get-PCNow;Add-PCHistory $p 'STALE_RUNNING_RECOVERED' 'SYSTEM' $p.stopReason;Save-AI5Project $p}}}
