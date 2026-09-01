param([int]$Port = 43125, [string]$HostName = '127.0.0.1')
$ErrorActionPreference = 'Stop'
if ($HostName -notin @('127.0.0.1','::1','localhost')) { throw 'AI5 HUB refuses non-loopback bind addresses' }
$CodeServerRoot = if ($global:AI5CodeServerRoot) { $global:AI5CodeServerRoot } else { $PSScriptRoot }
$ServerRoot = if ($env:AI5_SERVER_DATA_ROOT) { [IO.Path]::GetFullPath($env:AI5_SERVER_DATA_ROOT) } elseif ($global:AI5ServerRoot) { $global:AI5ServerRoot } else { $PSScriptRoot }
$AppRoot = Split-Path $CodeServerRoot

foreach ($module in @('router\Router.ps1', 'approval\ZeroApproval.ps1', 'approval\ApprovalRouting.ps1', 'adapters\MockAdapter.ps1', 'storage\Store.ps1','storage\Attachments.ps1','storage\LongMessageIngestion.ps1', 'security\Security.ps1', 'security\MobileSecurity.ps1', 'approval\ApprovalPolicy.ps1', 'notifications\PushNotification.ps1', 'task-service\CodexService.ps1', 'orchestrator\TaskEngine.ps1', 'orchestrator\ExecutionPolicy.ps1','orchestrator\AutonomousLoop.ps1','orchestrator\TaskQueue.ps1', 'adapters\ClaudeAdapter.ps1', 'adapters\SpecialistRegistry.ps1', 'adapters\BrowserSpecialistAdapter.ps1', 'adapters\ManusAdapter.ps1', 'adapters\NotebookLMAdapter.ps1', 'orchestrator\ResourceCommander.ps1', 'project-control\ProjectControl.ps1','command-center\CommandCenter.ps1','deployment\StableRuntime.ps1','github-bus\GitHubResultLoop.ps1')) {
    . ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $CodeServerRoot $module))))
}
Initialize-AI5Store $ServerRoot
Initialize-AI5Attachments $ServerRoot
Initialize-AI5LongMessages $ServerRoot
Initialize-AI5MobileSecurity $ServerRoot
Initialize-AI5ApprovalPolicy $ServerRoot
Initialize-AI5ApprovalRouting $ServerRoot
Initialize-AI5PushNotifications $ServerRoot $AppRoot
Initialize-AI5CodexService $ServerRoot $AppRoot
Initialize-AI5SpecialistRegistry $ServerRoot
Initialize-AI5ResourceCommander $ServerRoot
Initialize-AI5ProjectControl $ServerRoot $AppRoot
Initialize-AI5StableRuntime $ServerRoot $AppRoot
Initialize-AI5GitHubResultLoop $ServerRoot
$remoteBusRoot=if($env:AI5_GITHUB_BUS_REPO_ROOT){$env:AI5_GITHUB_BUS_REPO_ROOT}else{''}
try{Connect-AI5PrivateGitHubBusRemote $remoteBusRoot|Out-Null}catch{Write-AI5Log 'errors' 'github_bus_remote_connect_failed' @{error=$_.Exception.Message}}
Invoke-AI5ProjectRecovery
$Mock = if ($env:AI5_MOCK) { $env:AI5_MOCK -ne 'false' } else { $false }
$script:MockMode=$Mock
$Csrf = [guid]::NewGuid().ToString('N')
$listenAddress = if($HostName-eq'localhost'){[Net.IPAddress]::Loopback}else{[Net.IPAddress]::Parse($HostName)}
$listener = [Net.Sockets.TcpListener]::new($listenAddress, $Port)
$listener.Start()
Write-Host "AI5 HUB: http://$HostName`:$Port/ (mock=$Mock)"

function Send-Response($stream, [int]$status, [string]$type, [byte[]]$bytes, $extraHeaders = @{}) {
    $names = @{ 200 = 'OK'; 202 = 'Accepted'; 400 = 'Bad Request'; 401 = 'Unauthorized'; 403 = 'Forbidden'; 404 = 'Not Found'; 409 = 'Conflict'; 500 = 'Internal Server Error' }
    $custom = ''
    foreach ($entry in $extraHeaders.GetEnumerator()) { $custom += "$($entry.Key): $($entry.Value)`r`n" }
    $head = "HTTP/1.1 $status $($names[$status])`r`nContent-Type: $type`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nX-Frame-Options: DENY`r`nReferrer-Policy: no-referrer`r`nContent-Security-Policy: default-src 'self'; connect-src 'self'; img-src 'self'; style-src 'self'; script-src 'self'`r`n${custom}Connection: close`r`n`r`n"
    $header = [Text.Encoding]::ASCII.GetBytes($head)
    $stream.Write($header, 0, $header.Length)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
}

function Send-Json($stream, $value, [int]$status = 200, $extraHeaders = @{}) {
    $bytes = [Text.Encoding]::UTF8.GetBytes(($value | ConvertTo-Json -Depth 15))
    Send-Response $stream $status 'application/json; charset=utf-8' $bytes $extraHeaders
}

function Send-Static($stream, [string]$path) {
    $relative = if ($path -eq '/') { 'index.html' } else { $path.TrimStart('/') }
    $full = [IO.Path]::GetFullPath((Join-Path $AppRoot $relative))
    if (!$full.StartsWith([IO.Path]::GetFullPath($AppRoot)) -or !(Test-Path $full)) {
        Send-Json $stream @{ error = 'not_found' } 404
        return
    }
    $types = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8'; '.json' = 'application/json; charset=utf-8'; '.webmanifest' = 'application/manifest+json; charset=utf-8'; '.svg' = 'image/svg+xml'; '.png' = 'image/png'; '.ico' = 'image/x-icon' }
    Send-Response $stream 200 $types[[IO.Path]::GetExtension($full)] ([IO.File]::ReadAllBytes($full))
}

function Read-Request($stream) {
    $headerBytes = [Collections.Generic.List[byte]]::new()
    $tail = @()
    while ($true) {
        $value = $stream.ReadByte()
        if ($value -lt 0) { return $null }
        $headerBytes.Add([byte]$value)
        $tail = @($tail + [byte]$value | Select-Object -Last 4)
        if ($tail.Count -eq 4 -and $tail[0] -eq 13 -and $tail[1] -eq 10 -and $tail[2] -eq 13 -and $tail[3] -eq 10) { break }
        if ($headerBytes.Count -gt 65536) { throw 'headers_too_large' }
    }
    $lines = ([Text.Encoding]::ASCII.GetString($headerBytes.ToArray())).Split(@("`r`n"), [StringSplitOptions]::None)
    $parts = $lines[0].Split(' ')
    $headers = @{}
    foreach ($line in $lines[1..($lines.Count - 1)]) {
        $index = $line.IndexOf(':')
        if ($index -gt 0) { $headers[$line.Substring(0, $index).Trim()] = $line.Substring($index + 1).Trim() }
    }
    $length = 0
    if ($headers.ContainsKey('Content-Length')) { [int]::TryParse($headers['Content-Length'], [ref]$length) | Out-Null }
    if($length-gt7MB){throw 'body_too_large'}
    $bodyBytes = New-Object byte[] $length
    $read = 0
    while ($read -lt $length) {
        $count = $stream.Read($bodyBytes, $read, $length - $read)
        if ($count -le 0) { break }
        $read += $count
    }
    $body = if ($read -gt 0) { [Text.Encoding]::UTF8.GetString($bodyBytes, 0, $read) } else { '' }
    return [pscustomobject]@{ Method = $parts[0]; Path = ([uri]("http://local" + $parts[1])).AbsolutePath; Headers = $headers; Body = $body }
}

function Parse-Body($request) {
    if ($request.Body) { return $request.Body | ConvertFrom-Json }
    return [pscustomobject]@{}
}

function Update-State($task, [string]$status, [string]$label) {
    $task.status = $status
    $task.timeline += , [ordered]@{ status = $status; label = $label; at = [DateTime]::UtcNow.ToString('o') }
    Save-AI5Task $task
}

function Execute-Mock($task) {
    $null=Initialize-AI5LoopTask $task
    Add-AI5LineMessage $task 'zero' 'PLAN' '目的と完成条件を整理し、必要AIへ開始指示を出します。' 'plan'
    Update-State $task 'planning' 'Zero planning'
    Update-State $task 'running' "$($task.assignedPrimary) mock running"
    $task.result = Invoke-AI5MockAdapter $task
    Add-AI5AgentReport $task $task.assignedPrimary 'COMPLETE' 'Mock安全施工' $task.result.summary 'なし' 'Zero監査'
    Update-State $task 'reviewing' 'Zero reviewing'
    $judge=Invoke-AI5DoubleJudge $task
    Update-State $task $(if($judge.decision-eq'COMPLETE'){'completed'}else{'failed'}) "Autonomous Loop: $($judge.decision)"
    Write-AI5Log 'tasks' 'task_completed' @{ task_id = $task.taskId; status = 'completed'; adapter = 'mock' }
}

function Fail-Task($task, [string]$type, [string]$summary) {
    $task | Add-Member -NotePropertyName errorType -NotePropertyValue $type -Force
    $task.result = [ordered]@{ status = 'failed'; summary = $summary; details = @(); filesChanged = @(); tests = @(); warnings = @(); failureReason = $type; retryable = ($type -in @('bridge_unavailable', 'codex_unavailable', 'timeout','UNTRUSTED_WORKDIR')); next_action=$(if($type-eq'UNTRUSTED_WORKDIR'){'REPAIR_ENVIRONMENT_AND_RETRY'}else{'ESCALATE_ZERO'}); userActionRequired = ($type -eq 'authentication_failed') }
    Update-State $task 'failed' $summary
}

function Dispatch-Task($task) {
    if ($Mock) { Execute-Mock $task; return }
    if ($task.assignedPrimary -eq 'claude') {
      $null=Initialize-AI5LoopTask $task;Set-AI5TaskStatus $task 'RUNNING' 'Claudeレビュー中';$task.attempt++;$task.result=Invoke-AI5ClaudeAdapter $task
      Write-AI5Log 'tasks' 'claude_finished' @{task_id=$task.taskId;status=$task.result.status;summary=$task.result.summary;risks=($task.result.risks -join ' | ')}
      Add-AI5AgentReport $task 'claude' $task.result.status '独立レビュー・設計監査' $task.result.summary (@($task.result.risks)-join' / ') 'Zero統合監査'
      if($task.result.status-eq'SUCCESS'){$task.validation=[ordered]@{passed=$true;checks=@{claude_review=$true};checked_at=[DateTime]::UtcNow.ToString('o')};$task|Add-Member -NotePropertyName agent_results -NotePropertyValue @($task.result) -Force;$task.assignedSecondary=@($task.assignedSecondary+'claude'|Select-Object -Unique);$task.assignedPrimary='codex';$task.assigned_agent='codex';Add-AI5LineMessage $task 'zero' 'CONTINUE' 'Claude報告を受領。Codexへ最終技術監査を依頼します。' 'routing';Set-AI5TaskStatus $task 'RETRYING' 'Codex最終技術監査へ継続';Dispatch-Task $task}
      else{$task|Add-Member -NotePropertyName agent_results -NotePropertyValue @($task.result) -Force;$task.assignedPrimary='codex';$task.assigned_agent='codex';$task.result.next_action='REROUTE';Add-AI5LineMessage $task 'zero' 'REWORK' 'Claude結果をCodexへ再配分します。' 'routing';Set-AI5TaskStatus $task 'RETRYING' 'Claude失敗のためCodexへ再振り分け';Dispatch-Task $task};return
    }
    if($task.assignedPrimary-eq'manus'){
      $plan=New-AI5ManusDispatchPlan $task (Get-AI5ManusHealth);$task|Add-Member manus_dispatch $plan -Force
      if(!$plan.accepted){Fail-Task $task 'manus_unavailable' 'Manus WEB/APP route is unavailable';return}
      Set-AI5TaskStatus $task 'RUNNING' "Manus $($plan.route)へPrivate Task Bus経由で投入";Add-AI5LineMessage $task 'manus' 'RUNNING' "Manus $($plan.route)経路でread-only Taskを開始しました。" 'routing' $plan;Save-AI5Task $task
      try{Publish-AI5LocalTaskToGitHubBus $task|Out-Null;Invoke-AI5GitHubBusAutoSync 'Manus direct Task dispatch'|Out-Null}catch{Fail-Task $task 'manus_bus_unavailable' 'Manus Private Task Bus dispatch failed'};return
    }
    if ($task.assignedPrimary -in @('gemini','notebooklm')) { $original=$task.assignedPrimary;$task.assignedPrimary='codex';$task.assigned_agent='codex';$task.assignedSecondary=@($task.assignedSecondary+$original|Select-Object -Unique);Set-AI5TaskStatus $task 'RETRYING' "$original をCodex管理の正式経路へ再振り分け" }
    if ($task.assignedPrimary -ne 'codex') { Fail-Task $task 'adapter_unavailable' "$($task.assignedPrimary) adapter is not connected"; return }
    $health = Get-AI5CodexHealth
    if (!$health.available) { Fail-Task $task 'bridge_unavailable' 'Zero-Codex Bridge is unavailable'; return }
    try {
        $submitted = Submit-AI5CodexTask $task
        if (!$submitted.workerStarted) { Fail-Task $task 'bridge_unavailable' 'Codex worker could not start' }
    } catch {
        $errorText=$_.Exception.Message;$type=if($errorText-match'PROJECT_CONTEXT_MISSING|project_context'){'project_context_missing'}elseif($errorText-match'UNTRUSTED_WORKDIR|trusted directory'){'UNTRUSTED_WORKDIR'}else{'bridge_unavailable'}
        Write-AI5Log 'errors' 'bridge_submit_failed' @{ task_id = $task.taskId; error = $errorText;classification=$type }
        if($type-eq'UNTRUSTED_WORKDIR'-and$task.project_id){
          try{$task.projectContext=Get-AI5ProjectExecutionContext ([string]$task.project_id);Add-AI5LineMessage $task 'codex' 'REWORK' '作業場所を正本Projectから復元し、施工を自動再開しました。' 'environment_repair';Set-AI5TaskStatus $task 'RETRYING' 'REPAIR_ENVIRONMENT_AND_RETRY';$repaired=Submit-AI5CodexTask $task;if($repaired.workerStarted){return}}catch{Write-AI5Log 'errors' 'worktree_repair_failed' @{task_id=$task.taskId;error=$_.Exception.Message}}
        }
        Fail-Task $task $type $(if($type-eq'UNTRUSTED_WORKDIR'){'Codex作業場所の認識に失敗。自動修復が必要です。'}elseif($type-eq'project_context_missing'){'施工先Projectが未指定のため安全停止しました。'}else{'Zero-Codex Bridge submission failed'})
    }
}

function Invoke-AI5ManusResultRecovery {
    foreach($local in @(Get-AI5Tasks 100|Where-Object{$_.assignedPrimary-eq'manus'-and$_.status-in@('running','retrying')})){
      if(!$local.manus_dispatch){continue}
      if(!($local.manus_dispatch.PSObject.Properties.Name-contains'processedResultIds')){$local.manus_dispatch|Add-Member -NotePropertyName processedResultIds -NotePropertyValue @() -Force}
      $processed=@($local.manus_dispatch.processedResultIds)
      $busTasks=@(Get-AI5GitHubBusTasks|Where-Object{$_.task_id-eq$local.taskId-or$_.parent_task_id-eq$local.taskId}|Sort-Object created_at);$busIds=@($busTasks.task_id)
      $result=Get-AI5GitHubBusResults|Where-Object{$_.ai-eq'manus'-and$_.task_id-in$busIds-and$_.result_id-notin$processed}|Select-Object -Last 1
      if(!$result){continue}
      # Mark reconciled before branching so every exit path (reroute/redispatch/finalize) is exactly-once, even across repeated polls of the same still-latest bus result.
      $local.manus_dispatch.processedResultIds=@($processed+$result.result_id)
      $next=@(Get-AI5GitHubBusTasks|Where-Object{$_.parent_task_id-eq$result.task_id-and$_.status-in@('QUEUED','CLAIMED','RUNNING')}|Select-Object -Last 1)[0]
      if($result.result-ne'PASS'-and$next-and$next.assigned_ai-eq'manus'){$failedRoute=[string]$local.manus_dispatch.route;$fallbackRoute=[string]$local.manus_dispatch.fallback;if(!$fallbackRoute){Fail-Task $local 'manus_route_failed' 'Manus fallback route unavailable';Save-AI5Task $local;continue};$local.status='retrying';$local.manus_dispatch.route=$fallbackRoute;$local.manus_dispatch.fallback='';$local.manus_dispatch.attempted=$true;Add-AI5LineMessage $local 'zero' 'REWORK' "Manus $failedRoute 失敗を確認。$fallbackRoute fallbackへ1回だけ再投入します。" 'routing';Save-AI5Task $local;continue}
      if($result.result-ne'PASS'-and$next-and$next.assigned_ai-ne'manus'){
        # Both WEB and APP were exhausted; the Collector already redispatched a grandchild task off the Manus path (e.g. to claude). Keep lineage traceable and leave Codex uninvolved instead of finalizing as a bare failure.
        $local.manus_dispatch|Add-Member -NotePropertyName fallbackTaskId -NotePropertyValue ([string]$next.task_id) -Force
        $local.manus_dispatch|Add-Member -NotePropertyName fallbackAssignedAi -NotePropertyValue ([string]$next.assigned_ai) -Force
        $local.result=ConvertFrom-AI5ManusBusResult $result
        Add-AI5AgentReport $local 'manus' 'BLOCKED' "Manus $($local.manus_dispatch.route) read-only実行" $local.result.summary (@($local.result.issues)-join' / ') 'Zero統合監査'
        Add-AI5LineMessage $local 'zero' 'REDISPATCH' "Manus WEB/APP双方失敗を確認。$($next.assigned_ai)へ再配分済み（Codex未介入、linkage: $($next.task_id)）。" 'routing'
        $local|Add-Member -NotePropertyName errorType -NotePropertyValue 'manus_exhausted_redispatched' -Force
        Set-AI5TaskStatus $local 'BLOCKED' "Manus WEB/APP双方失敗。$($next.assigned_ai)へ再配分済み"
        Save-AI5Task $local;continue
      }
      $local.result=ConvertFrom-AI5ManusBusResult $result;Add-AI5AgentReport $local 'manus' $(if($result.result-eq'PASS'){'COMPLETE'}else{'BLOCKED'}) "Manus $($local.manus_dispatch.route) read-only実行" $local.result.summary (@($local.result.issues)-join' / ') 'Zero統合監査'
      if($result.result-eq'PASS'){$local.validation=[ordered]@{passed=$true;checks=[ordered]@{manus_result_bus=$true;idempotency=$true};checked_at=[DateTime]::UtcNow.ToString('o')};$judge=Invoke-AI5DoubleJudge $local;Set-AI5TaskStatus $local $(if($judge.decision-eq'COMPLETE'){'COMPLETED'}else{'FAILED'}) "Manus Result回収: Zero $($judge.decision)"}else{Fail-Task $local 'manus_route_failed' $local.result.summary};Save-AI5Task $local
    }
}

function Restore-AI5TaskFromStoredCodexResult($task) {
    $stored = Get-AI5StoredCodexResult ([string]$task.taskId)
    if (!$stored -or $stored.status -ne 'success') { return $false }
    $summary = if ($stored.result) { [string]$stored.result } else { 'Codex task completed' }
    $task | Add-Member bridge ([ordered]@{taskId=$stored.task_id;status=$stored.status;sessionId=$stored.codex_session_id;attemptCount=$stored.attempt_count;startedAt=$stored.started_at;finishedAt=$stored.finished_at}) -Force
    $task.result = [ordered]@{task_id=$task.taskId;agent='codex';status='success';summary=$summary;details=@($stored.details);filesChanged=@($stored.files_changed);tests=@($stored.tests);warnings=@($stored.warnings);commitId=$stored.commit_id;failureReason=$null;retryable=$false;userActionRequired=$false;findings=@($stored.details);changes=@($stored.files_changed);artifacts=@($stored.files_changed);risks=@($stored.warnings);next_action='VALIDATE';needs_human=$false;human_reason=$null}
    $task.validation=[ordered]@{passed=$true;checks=[ordered]@{result_schema=$true;tests=(@($stored.tests).Count-gt 0);bridge_success=$true;restart_reconciliation=$true};checked_at=[DateTime]::UtcNow.ToString('o')}
    $null=Initialize-AI5LoopTask $task
    if(!@($task.agent_reports|Where-Object{$_.agent-eq'codex'-and$_.state-eq'COMPLETE'}).Count){Add-AI5AgentReport $task 'codex' 'COMPLETE' '保存済みBridge結果を再照合' $summary 'なし' 'Zero統合監査'}
    $judge=Invoke-AI5DoubleJudge $task
    Set-AI5TaskStatus $task $(if($judge.decision-eq'COMPLETE'){'COMPLETED'}else{'FAILED'}) "再起動復元: Zero + Codex $($judge.decision)"
    Write-AI5Log 'tasks' 'stored_codex_result_restored' @{task_id=$task.taskId;decision=$judge.decision}
    return $true
}

function Get-AI5MachineIdentity {
    $hostName = [Environment]::MachineName.ToUpperInvariant()
    $displayName = if ($env:AI5_MACHINE_DISPLAY_NAME) { [string]$env:AI5_MACHINE_DISPLAY_NAME } elseif ($hostName -eq 'LAPTOP-32D9HNI7') { '富士通' } else { $hostName }
    [ordered]@{ id = $hostName.ToLowerInvariant(); hostName = $hostName; displayName = $displayName; state = 'online'; checkedAt = [DateTime]::UtcNow.ToString('o') }
}

function Get-MobileHealth {
    $bridge = Get-AI5CodexHealth
    $worker = 'idle'
    $lockPath = Join-Path $ServerRoot 'runtime\codex-worker.lock'
    if (Test-Path $lockPath) {
        $pidText = (Get-Content -Raw $lockPath -ErrorAction SilentlyContinue).Trim()
        if ($pidText -match '^\d+$' -and (Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue)) { $worker = 'running' }
    }
    $tailscaleState = 'not_installed'
    try{$tailService=Get-Service -Name 'Tailscale' -ErrorAction Stop;$tailscaleState=if($tailService.Status-eq'Running'){'service_running_unverified'}else{'service_stopped'}}catch{}
    return [ordered]@{ machine = (Get-AI5MachineIdentity); pc = 'online'; runtime = 'online'; server = 'online'; localApi = 'online'; bridge = $(if ($bridge.available) { 'ready' } else { 'unavailable' }); codex = $(if ($bridge.available) { 'available' } else { 'unavailable' }); worker = $worker; tailscale = $tailscaleState; serve = $(if($tailscaleState-eq'service_running_unverified'){'configured_unverified'}else{'unavailable'}); remote = $tailscaleState }
}

function New-Task($body, [string]$idem) {
    $target=if($body.target){[string]$body.target}else{'auto'}
    if($target-in@('auto','zero')-and$body.message-match'(?i)^\s*@(codex|claude|gemini|manus|notebooklm|all)\b'){$target=$Matches[1].ToLowerInvariant()}
    $route = Get-AI5Route $body.message $target
    $id = if ($body.taskId) { $body.taskId } else { Get-AI5NextTaskId }
    $approval = if ($route.requiresApproval) { [ordered]@{ type = $route.approvalType; summary = '本人の最終承認が必要です'; status = 'pending'; zero_review = (Get-AI5ZeroApprovalReview $route) } } else { $null }
    $now=[DateTime]::UtcNow.ToString('o');$displayObjective=if(([string]$route.objective).Length-gt240){([string]$route.objective).Substring(0,240)+'…'}else{[string]$route.objective}
    $task=[pscustomobject][ordered]@{
        task_id=$id;taskId = $id; parent_task_id=$null;title=$displayObjective;conversationId = $body.conversationId;reply_to=$body.replyTo;attachment_id=$body.attachmentId; message = Protect-AI5Text $body.message;original_message_length=([string]$body.message).Length;long_message_id=$body.longMessageId;objective = $displayObjective;constraints=@($body.constraints);project_id=$body.projectId;queue_reason='';queue_position=0;execution_class=''
        source = $(if ($body.source) { $body.source } else { 'teppei' }); priority = $(if ($body.priority) { $body.priority } else { 'normal' }); requested_read_only=[bool]$body.readOnly
        product=$body.product;taskLabel=$body.taskLabel;accountService=$body.accountService;service=$body.service;account=$body.account;channel=$body.channel;amount=$body.amount;externalImpact=$body.externalImpact;reversible=$body.reversible;approvalReason=$body.approvalReason;afterApproval=$body.afterApproval;whatDoesNotChange=@($body.whatDoesNotChange);ownerAction=$body.ownerAction;expiresAt=$body.expiresAt
        assigned_agent=$route.primary;requested_target=$route.requestedTarget;routing_mode=$route.routingMode;status = $(if ($route.requiresApproval) { 'waiting_approval' } else { 'queued' });canonical_status=$(if ($route.requiresApproval){'WAITING_APPROVAL'}else{'RECEIVED'});approval_level=$(if($route.requiresApproval){'RED'}elseif($route.risk-eq'medium'){'YELLOW'}else{'GREEN'});attempt=0;max_attempts=3;assignedPrimary = $route.primary; assignedSecondary = $route.secondary
        requiresApproval = $route.requiresApproval; approval = $approval; field_mode=$(if($null-ne$body.fieldMode){[bool]$body.fieldMode}else{$true}); field_decision=$null; execution_plan=(Get-AI5ExecutionPlan $route); failure_fingerprints=@(); route = $route; validation=[ordered]@{};artifacts=@();result = $null
        timeline = @([ordered]@{ status = 'RECEIVED'; label = '依頼受付'; at = $now })
        children=@();idempotencyKey = $idem; created_at=$now;updated_at=$now;createdAt = $now; updatedAt = $now
    }
    $null=Initialize-AI5LoopTask $task
    if($task.project_id){$task|Add-Member -NotePropertyName projectContext -NotePropertyValue (Get-AI5ProjectExecutionContext ([string]$task.project_id)) -Force}
    Add-AI5LineMessage $task 'zero' 'PLAN' "目的を整理しました。$($route.primary)を中心に開始します。" 'plan' @{target=$route.requestedTarget;doneWhen=$route.doneWhen}
    $task.children=New-AI5Children $task $route
    $task.field_decision=Get-AI5FieldModeDecision $route $task.field_mode
    return $task
}

function Submit-AI5TaskBody($body,[string]$idem) {
    if($body.attachmentId -and !(Get-AI5AttachmentPath ([string]$body.attachmentId))){throw'attachment_not_found'}
    $problem=Test-AI5Instruction $body.message -Long:([bool]$body.longMessageId);if($problem){throw$problem}
    if($body.taskId-and$body.taskId-notmatch'^task_[A-Za-z0-9_.-]{3,80}$'){throw'invalid_task_id'}
    if($body.taskId){$same=Get-AI5Task $body.taskId;if($same){return$same}}
    if($idem){$existing=Get-AI5Tasks|Where-Object{$_.idempotencyKey-eq$idem}|Select-Object -First 1;if($existing){return$existing}}
    $task=New-Task $body $idem
    $task=Resolve-AI5ResourceAssignment $task
    $task=Resolve-AI5TaskApprovalPolicy $task
    $decision=Get-AI5TaskQueueDecision $task @(Get-AI5Tasks 100) @(Get-AI5ActiveLocks)
    $task.execution_class=$(if($decision.readOnly){'READ_ONLY'}else{'WRITE'});if($decision.projectId){$task.project_id=$decision.projectId}
    if($decision.action-eq'QUEUE'){$task.queue_reason=$decision.reason;$task.timeline+=,[ordered]@{status='QUEUED';label='同一ProjectのWriter完了後にZeroが再評価';at=[DateTime]::UtcNow.ToString('o')};$task.queue_position=@(Get-AI5Tasks 100|Where-Object{$_.queue_reason-and$_.status-eq'queued'}).Count+1}
    if($task.requiresApproval){$task.timeline+=,[ordered]@{status='WAITING_APPROVAL';label=$(if($task.approval.ownerOperationRequired){'鉄兵の本人操作が必要'}else{'AI5 HUBで鉄兵の確認待ち'});at=[DateTime]::UtcNow.ToString('o')}}else{$task.timeline+=,[ordered]@{status='AUTO_APPROVED';label='AI5安全判定で自動承認';at=[DateTime]::UtcNow.ToString('o')}}
    Save-AI5Task $task;Write-AI5Log 'tasks' 'task_created' @{task_id=$task.taskId;primary=$task.assignedPrimary;approval=$task.requiresApproval;queue_reason=$task.queue_reason;long_message_id=$task.long_message_id};try{Publish-AI5LocalTaskToGitHubBus $task|Out-Null;Invoke-AI5GitHubBusAutoSync 'AI5 LINE Task sync'|Out-Null}catch{Write-AI5Log 'errors' 'github_task_publish_failed' @{task_id=$task.taskId;error=$_.Exception.Message}}
    if(!$task.requiresApproval-and!$task.queue_reason){Dispatch-Task $task};$task
}

function Invoke-AI5QueuedTaskDispatch {
    $candidate=Get-AI5Tasks 100|Where-Object{$_.status-eq'queued'-and$_.queue_reason-eq'SINGLE_WRITER_BUSY'}|Sort-Object createdAt|Select-Object -First 1;if(!$candidate){return}
    $decision=Get-AI5TaskQueueDecision $candidate @(Get-AI5Tasks 100) @(Get-AI5ActiveLocks);if($decision.action-ne'DISPATCH'){return}
    $candidate.queue_reason='';$candidate.queue_position=0;$candidate|Add-Member queue_revalidated_at ([DateTime]::UtcNow.ToString('o')) -Force
    Add-AI5LineMessage $candidate 'zero' 'CONTINUE' 'Writer解放を確認し、最新状態を再評価して施工を開始します。' 'queue';Save-AI5Task $candidate
    Write-AI5Log 'tasks' 'queued_task_released' @{task_id=$candidate.taskId;project_id=$candidate.project_id};Dispatch-Task $candidate
}
function Invoke-AI5AutonomousRedispatch {$candidate=Get-AI5Tasks 100|Where-Object{$_.status-eq'retrying'-and$_.loop_state.decision-eq'REDISPATCH'}|Sort-Object updatedAt|Select-Object -First 1;if(!$candidate){return};$candidate.loop_state.decision='CONTINUE';$candidate.loop_state.updatedAt=[DateTime]::UtcNow.ToString('o');Add-AI5LineMessage $candidate 'zero' 'CONTINUE' "$($candidate.assignedPrimary)へ再配分したTaskを自動再開します。" 'routing';Save-AI5Task $candidate;Dispatch-Task $candidate}

function Restore-AI5LocalTasksFromGitHubBus {$count=0;foreach($remote in @(Get-AI5GitHubBusTasks|Where-Object{$_.status-in@('QUEUED','CLAIMED','RUNNING','REVIEW','RETRY')-and!$_.target_device_id})){if(Get-AI5Task $remote.task_id){continue};$body=[pscustomobject]@{taskId=$remote.task_id;message=$remote.instructions;target=$remote.assigned_ai;source='PRIVATE_GITHUB_BUS';priority=$remote.priority;conversationId='github-result-loop';projectId=$remote.project_id;constraints=@('restored from verified private Result Bus')};$task=New-Task $body ('remote:'+ $remote.task_id);$task.attempt=[int]$remote.retry_count;$task.loop_state.cycle=[int]$remote.retry_count;Add-AI5LineMessage $task 'system' 'CONTINUE' 'Private Result Busから未完Loopを復元しました。Zeroが安全性を再評価します。' 'recovery';Save-AI5Task $task;$count++};$count}
function Get-AI5LocalProjectLoopStatus([string]$ProjectId){$task=Get-AI5Tasks 100|Where-Object{$_.project_id-eq$ProjectId}|Sort-Object updatedAt|Select-Object -Last 1;if(!$task){return [ordered]@{state='IDLE';attemptCount=0;sameFailureCount=0;redispatchCount=0;dailyExecutionCount=0;lastDecision='NONE';approvalWaiting=$false}};[ordered]@{state=$task.status;taskId=$task.taskId;attemptCount=[int]$task.loop_state.attemptCount;sameFailureCount=[int]$task.loop_state.sameFailureCount;redispatchCount=[int]$task.loop_state.redispatchCount;dailyExecutionCount=[int]$task.loop_state.dailyExecutionCount;lastDecision=[string]$task.loop_state.decision;approvalWaiting=($task.status-eq'waiting_approval')}}

try{Restore-AI5LocalTasksFromGitHubBus|Out-Null}catch{Write-AI5Log 'errors' 'github_bus_local_restore_failed' @{error=$_.Exception.Message}}
if(!$Mock){foreach($recoverable in @(Get-AI5Tasks 100|Where-Object{$_.assignedPrimary-eq'codex'-and(($_.status-in@('running','retrying'))-or($_.status-eq'queued'-and$_.attempt-eq0-and!$_.queue_reason)-or($_.status-eq'failed'-and$_.result.retryable-and!$_.result.userActionRequired-and$_.attempt-lt$_.max_attempts-and([DateTime]::UtcNow-[DateTime]::Parse($_.updatedAt)).TotalHours-lt24))}|Select-Object -First 1)){try{if(Restore-AI5TaskFromStoredCodexResult $recoverable){continue};if($recoverable.status-eq'failed'){Set-AI5TaskStatus $recoverable 'RETRYING' 'PC再起動後に安全な未完Taskを1件復旧'};Dispatch-Task $recoverable}catch{Write-AI5Log 'errors' 'startup_task_recovery_failed' @{task_id=$recoverable.taskId;error=$_.Exception.Message}}}}
$NextApprovalScheduleAt=[DateTimeOffset]::MinValue
try {
    while ($true) {
        if(!$listener.Pending()){
            $scheduler=Get-AI5SchedulerStatus
            $due=!$scheduler.nextScan-or([DateTimeOffset]::Parse($scheduler.nextScan)-le[DateTimeOffset]::Now)
            if($due){try{Invoke-AI5ProjectScan -Fetch $true|Out-Null}catch{Write-AI5Log 'errors' 'project_scheduler_failed' @{error=$_.Exception.Message}}}
            try{Invoke-AI5QueuedTaskDispatch}catch{Write-AI5Log 'errors' 'queued_task_dispatch_failed' @{error=$_.Exception.Message}}
            try{Invoke-AI5AutonomousRedispatch}catch{Write-AI5Log 'errors' 'autonomous_redispatch_failed' @{error=$_.Exception.Message}}
            try{Invoke-AI5ManusResultRecovery}catch{Write-AI5Log 'errors' 'manus_result_recovery_failed' @{error=$_.Exception.Message}}
            try{$published=0;foreach($terminal in @(Get-AI5Tasks 100|Where-Object{$_.result-and$_.status-in@('completed','failed','waiting_approval')-and[int]$_.github_bus_published_version-ne[Math]::Max(1,([int]$_.attempt+1))}|Select-Object -First 5)){$version=[Math]::Max(1,([int]$terminal.attempt+1));$publication=Publish-AI5LocalTaskToGitHubBus $terminal;$terminal|Add-Member github_bus_published_version $version -Force;Save-AI5Task $terminal;if($publication.published-eq'RESULT'){$published++}};if($published){Invoke-AI5GitHubBusAutoSync 'AI5 LINE Result and Decision sync'|Out-Null}}catch{Write-AI5Log 'errors' 'github_task_result_publish_failed' @{error=$_.Exception.Message}}
            try{$collected=Invoke-AI5GitHubResultCollector;if($collected.processed-gt0){Invoke-AI5GitHubBusAutoSync|Out-Null}}catch{Write-AI5Log 'errors' 'github_result_collector_failed' @{error=$_.Exception.Message}}
            if([DateTimeOffset]::Now-ge$NextApprovalScheduleAt){try{$null=Invoke-AI5ApprovalNotificationSchedule -Tasks @(Get-AI5Tasks 100)}catch{Write-AI5Log 'errors' 'approval_notification_schedule_failed' @{error=$_.Exception.Message}};$NextApprovalScheduleAt=[DateTimeOffset]::Now.AddSeconds(30)}
            Start-Sleep -Milliseconds 200
            continue
        }
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        try {
            $request = Read-Request $stream
            if (!$request) { continue }
            $path = $request.Path
            $method = $request.Method
            if ($path -eq '/api/session' -and $method -eq 'GET') {
                $session = Get-AI5Session $request
                if ($session) { Send-Json $stream @{ authenticated = $true; login = $session.login; name = $session.name; expiresAt = $session.expiresAt; local = [bool]$session.local } }
                else { Send-Json $stream @{ authenticated = $false; identityAvailable = [bool](Get-AI5TailscaleIdentity $request) } 401 }
                continue
            }
            if ($path -eq '/api/session' -and $method -eq 'POST') {
                if (Test-AI5LoopbackHost $request) { Send-Json $stream @{ authenticated = $true; login = 'local-windows'; local = $true }; continue }
                $identity = Get-AI5TailscaleIdentity $request
                $origin = [string]$request.Headers['Origin']
                $hostValue = [string]$request.Headers['Host']
                if (!$identity -or ($origin -and $origin -ne "https://$hostValue")) { Write-AI5Log 'security' 'login_rejected' @{ host = $hostValue }; Send-Json $stream @{ error = 'authentication_failed' } 401; continue }
                $created = New-AI5Session $identity
                Write-AI5Log 'remote_access' 'login' @{ login = $identity.login }
                Send-Json $stream @{ authenticated = $true; login = $created.record.login; name = $created.record.name; expiresAt = $created.record.expiresAt } 200 @{ 'Set-Cookie' = $created.cookie }
                continue
            }
            if (!(Test-AI5LoopbackHost $request) -and !(Get-AI5TailscaleIdentity $request)) { Write-AI5Log 'security' 'anonymous_remote_rejected' @{ path = $path }; Send-Json $stream @{ error = 'authentication_required' } 401; continue }
            $session = Get-AI5Session $request
            if ($path.StartsWith('/api/') -and !$session) { Write-AI5Log 'security' 'anonymous_rejected' @{ path = $path }; Send-Json $stream @{ error = 'authentication_required' } 401; continue }
            if ($path -eq '/api/logout' -and $method -eq 'POST') { $cookie = Remove-AI5Session $request; Write-AI5Log 'remote_access' 'logout' @{ login = $session.login }; Send-Json $stream @{ authenticated = $false } 200 @{ 'Set-Cookie' = $cookie }; continue }
            if ($path.StartsWith('/api/') -and $method -ne 'GET' -and $Csrf -ne $request.Headers['X-AI5-CSRF']) {
                Write-AI5Log 'security' 'csrf_rejected' @{ path = $path }
                Send-Json $stream @{ error = 'csrf' } 403
                continue
            }
            if ($method -eq 'GET' -and $path -eq '/api/health') {$mobileHealth=Get-MobileHealth;Send-Json $stream @{ ok = $true; service = 'ai5-hub'; mock = $Mock; csrfToken = $Csrf; machine=$mobileHealth.machine;components = $mobileHealth; deployment=(Get-AI5Deployment); time = [DateTime]::UtcNow.ToString('o') }; continue }
            if ($method -eq 'GET' -and $path -eq '/api/update-status') {Send-Json $stream (Get-AI5Deployment);continue}
            if ($method -eq 'GET' -and $path -eq '/api/status') {
                $bridgeHealth = Get-AI5CodexHealth
                $claudeHealth = Get-AI5ClaudeHealth
                $geminiHealth = Get-AI5SpecialistHealth 'gemini'
                $manusHealth = Get-AI5ManusHealth
                $notebookHealth = Get-AI5NotebookLMHealth
                $codexState = if ($Mock -or $bridgeHealth.available) { 'ready' } else { 'offline' }
                $codexConnection = if ($Mock) { 'mock' } elseif ($bridgeHealth.available) { 'official_cli' } else { 'not_connected' }
                Send-Json $stream @{ mode = $(if ($Mock) { 'mock' } else { 'live' }); bridge = $bridgeHealth; agents = @{ zero = @{ state = 'ready'; connection = 'local' }; codex = @{ state = $codexState; connection = $codexConnection }; gemini = @{ state = $(if ($Mock -or $geminiHealth.available) { 'ready' } else { 'offline' }); connection = $(if ($Mock) { 'mock' } else { $geminiHealth.connection });quota=$geminiHealth.quota }; claude = @{ state = $(if ($Mock -or $claudeHealth.available) { 'ready' } else { 'offline' }); connection = $(if ($Mock) { 'mock' } else { $claudeHealth.connection });quota=$claudeHealth.quota }; manus = @{ state = $(if ($Mock -or $manusHealth.available) { 'ready' } else { 'offline' }); connection = $(if ($Mock) { 'mock' } else { $manusHealth.connection });quota=$manusHealth.quota;app=$manusHealth.app;web=$manusHealth.web;route=$manusHealth.route }; notebooklm = @{ state = $(if ($Mock -or $notebookHealth.available) { 'ready' } else { 'offline' }); connection = $(if ($Mock) { 'mock' } else { $notebookHealth.connection });quota=$notebookHealth.quota;mode='read_only' } }; tasks = @(Get-AI5Tasks) }
                continue
            }
            if ($method -eq 'GET' -and $path -eq '/api/command-center') { Send-Json $stream (Get-AI5CommandCenter);continue }
            if ($method -eq 'GET' -and $path -eq '/api/chat') {$level=if($request.Headers['X-AI5-Chat-Level']){[string]$request.Headers['X-AI5-Chat-Level']}else{'NORMAL'};if($level-notin@('SIMPLE','NORMAL','DETAIL')){$level='NORMAL'};Send-Json $stream @{level=$level;messages=@((Get-AI5LineMessages @(Get-AI5Tasks 100) $level)+@(Get-AI5GitHubBusLineMessages)|Sort-Object at)};continue }
            if ($method -eq 'GET' -and $path -eq '/api/github-bus/status') {Send-Json $stream (Get-AI5GitHubBusStatus);continue}
            if ($method -eq 'GET' -and $path -eq '/api/github-bus/inbox') {Send-Json $stream @{items=@(Get-AI5ZeroInbox)};continue}
            if ($path-match'^/api/github-bus/queues/(codex|claude|gemini|manus|notebooklm)$'-and$method-eq'GET'){Send-Json $stream @{tasks=@(Get-AI5GitHubBusTasks $Matches[1])};continue}
            if ($method -eq 'POST' -and $path -eq '/api/github-bus/tasks') {try{$created=New-AI5GitHubBusTask (Parse-Body $request);Invoke-AI5GitHubBusAutoSync 'AI5 Task Bus sync'|Out-Null;Send-Json $stream $created 201}catch{Send-Json $stream @{error=$_.Exception.Message} 400};continue}
            if ($path-match'^/api/github-bus/tasks/([^/]+)/claim$'-and$method-eq'POST'){try{$body=Parse-Body $request;Send-Json $stream (Claim-AI5GitHubBusTask $Matches[1] ([string]$body.ai))}catch{Send-Json $stream @{error=$_.Exception.Message} 409};continue}
            if ($path-match'^/api/github-bus/tasks/([^/]+)/heartbeat$'-and$method-eq'POST'){try{$body=Parse-Body $request;Send-Json $stream (Update-AI5GitHubBusHeartbeat $Matches[1] ([string]$body.ai))}catch{Send-Json $stream @{error=$_.Exception.Message} 409};continue}
            if ($method -eq 'POST' -and $path -eq '/api/github-bus/results') {try{$saved=New-AI5GitHubBusResult (Parse-Body $request);$collection=Invoke-AI5GitHubResultCollector;Invoke-AI5GitHubBusAutoSync 'AI5 Result Bus sync'|Out-Null;Send-Json $stream @{saved=$saved;collector=$collection} 201}catch{Send-Json $stream @{error=$_.Exception.Message} 400};continue}
            if ($method -eq 'GET' -and $path -eq '/api/push/public-key') { $key=Get-AI5PushPublicKey;if($key){Send-Json $stream @{available=$true;publicKey=$key;background=$true}}else{Send-Json $stream @{available=$false;error='push_unavailable'} 503};continue }
            if ($method -eq 'POST' -and $path -eq '/api/attachments') {try{Send-Json $stream (Save-AI5Attachment (Parse-Body $request)) 201}catch{Send-Json $stream @{error=$_.Exception.Message} 400};continue}
            if($method-eq'POST'-and$path-eq'/api/message-drafts'){try{Send-Json $stream (New-AI5LongMessageDraft (Parse-Body $request)) 201}catch{Send-Json $stream @{error=$_.Exception.Message} 400};continue}
            if($path-match'^/api/message-drafts/([^/]+)$'-and$method-eq'GET'){try{Send-Json $stream (Get-AI5LongMessageStatus $Matches[1])}catch{Send-Json $stream @{error=$_.Exception.Message} 404};continue}
            if($path-match'^/api/message-drafts/([^/]+)/chunks/(\d+)$'-and$method-eq'POST'){try{Send-Json $stream (Save-AI5LongMessageChunk $Matches[1] ([int]$Matches[2]) (Parse-Body $request)) 202}catch{Send-Json $stream @{error=$_.Exception.Message} 400};continue}
            if($path-match'^/api/message-drafts/([^/]+)/commit$'-and$method-eq'POST'){$draftId=$Matches[1];try{$completed=Complete-AI5LongMessage $draftId;if($completed.alreadyCompleted){$existing=Get-AI5Task $completed.taskId;if(!$existing){throw'completed_task_not_found'};Send-Json $stream $existing;continue};$body=Parse-Body $request;$body|Add-Member message $completed.message -Force;$body|Add-Member longMessageId $draftId -Force;$task=Submit-AI5TaskBody $body ("long:$draftId");Set-AI5LongMessageCompleted $completed $task.taskId;Send-Json $stream $task 202}catch{Send-Json $stream @{error=$_.Exception.Message} 400};continue}
            if ($method -eq 'POST' -and $path -eq '/api/push/subscribe') { try{Send-Json $stream (Save-AI5PushSubscription (Parse-Body $request)) 201}catch{Send-Json $stream @{error=$_.Exception.Message} 400};continue }
            if ($method -eq 'GET' -and $path -eq '/api/projects') { Send-Json $stream (Get-AI5ProjectSummary); continue }
            if ($method -eq 'POST' -and $path -eq '/api/projects') { $body=Parse-Body $request; if(!$body.name-or!$body.projectId){Send-Json $stream @{error='name_and_project_id_required'} 400;continue}; try{Send-Json $stream (New-AI5Project $body) 202}catch{Send-Json $stream @{error=$_.Exception.Message} 409}; continue }
            if ($method -eq 'GET' -and $path -eq '/api/projects/repositories') { Send-Json $stream @{repositories=@(Get-AI5RepositoryCandidates)};continue }
            if ($path -match '^/api/projects/(?!(system|repositories)$)([^/]+)$' -and $method -eq 'GET') { try{$project=Get-AI5Project $Matches[2]}catch{$project=$null};if($project){$project|Add-Member githubResultLoop (Get-AI5GitHubBusProjectStatus $project.projectId) -Force;$project|Add-Member autonomousLoop (Get-AI5LocalProjectLoopStatus $project.projectId) -Force;Send-Json $stream $project}else{Send-Json $stream @{error='not_found'} 404};continue }
            if ($path -match '^/api/projects/([^/]+)/state$' -and $method -eq 'POST') { $project=Get-AI5Project $Matches[1];if(!$project){Send-Json $stream @{error='not_found'} 404;continue};Send-Json $stream (Set-AI5ProjectState $project (Parse-Body $request) 'TEPPEI');continue }
            if ($path -match '^/api/projects/([^/]+)/auto-execution$' -and $method -eq 'POST') { $project=Get-AI5Project $Matches[1];if(!$project){Send-Json $stream @{error='not_found'} 404;continue};$body=Parse-Body $request;$mode=if($body.mode){[string]$body.mode}elseif([bool]$body.enabled){'DRY_RUN'}else{'OFF'};try{Send-Json $stream (Set-AI5ProjectAuto $project $mode)}catch{Send-Json $stream @{error=$_.Exception.Message} 400};continue }
            if ($path -match '^/api/projects/([^/]+)/execution-check$' -and $method -eq 'GET') { $project=Get-AI5Project $Matches[1];if(!$project){Send-Json $stream @{error='not_found'} 404}else{Send-Json $stream (Test-AI5ProjectExecution $project)};continue }
            if ($method -eq 'POST' -and $path -eq '/api/projects/scan') { $body=Parse-Body $request;Send-Json $stream (Invoke-AI5ProjectScan -Fetch ($body.fetch-ne$false) -DryRun ([bool]$body.dryRun));continue }
            if ($method -eq 'GET' -and $path -eq '/api/projects/system') { $projects=@(Get-AI5Projects);$locks=@(Get-AI5ActiveLocks);$bridge=Get-AI5CodexHealth;Send-Json $stream @{scheduler=Get-AI5SchedulerStatus;bridge=$bridge;locks=$locks;queue=@(Get-ChildItem (Join-Path $ServerRoot 'data\codex-inbox') -Filter '*.json' -ErrorAction SilentlyContinue).Count;autoLive=@($projects|Where-Object{$_.autoExecution.mode-eq'LIVE'}).Count;dryRun=@($projects|Where-Object{$_.autoExecution.mode-eq'DRY_RUN'}).Count;creditStops=@($projects|Where-Object{$_.stopCode-eq'CREDIT_PROTECTION_STOP'}).Count;approvalStops=@($projects|Where-Object{$_.status-eq'APPROVAL_REQUIRED'}).Count;githubBus=(Get-AI5GitHubBusStatus)};continue }
            if ($path -match '^/api/projects/([^/]+)/sync$' -and $method -eq 'POST') { $project=Get-AI5Project $Matches[1];if(!$project){Send-Json $stream @{error='not_found'} 404}else{Send-Json $stream (Sync-AI5ProjectGit $project)};continue }
            if ($method -eq 'POST' -and $path -eq '/api/tasks') {
                $body = Parse-Body $request
                $idem = $request.Headers['Idempotency-Key']
                try{$task=Submit-AI5TaskBody $body $idem}catch{Send-Json $stream @{error=$_.Exception.Message} 400;continue}
                if ($task.requiresApproval -and $task.approval.contextComplete) { $task | Add-Member -NotePropertyName approvalToken -NotePropertyValue (New-AI5ApprovalToken $task.taskId) -Force }
                Send-Json $stream $task 202
                continue
            }
            if ($method -eq 'GET' -and $path -eq '/api/tasks') { Send-Json $stream @{ tasks=@(Get-AI5Tasks 100) }; continue }
            if ($path -match '^/api/tasks/([^/]+)$' -and $method -eq 'GET') { $task = Get-AI5Task $Matches[1]; if ($task -and !$Mock -and !$task.queue_reason -and $task.assignedPrimary -eq 'codex' -and $task.status -in @('queued', 'running')) { Start-AI5CodexWorker | Out-Null }; if ($task) { if ($task.status -eq 'waiting_approval' -and $task.approval.contextComplete) { $task | Add-Member -NotePropertyName approvalToken -NotePropertyValue (New-AI5ApprovalToken $task.taskId) -Force }; Send-Json $stream $task } else { Send-Json $stream @{ error = 'not_found' } 404 }; continue }
            if ($path -match '^/api/tasks/([^/]+)/result$' -and $method -eq 'GET') { $task = Get-AI5Task $Matches[1]; if (!$task) { Send-Json $stream @{ error = 'not_found' } 404 } elseif ($task.result) { Send-Json $stream @{ taskId = $task.taskId; status = $task.status; result = $task.result; bridge = $task.bridge } } else { Send-Json $stream @{ taskId = $task.taskId; status = $task.status; result = $null } 202 }; continue }
            if ($path -match '^/api/tasks/([^/]+)/approve$' -and $method -eq 'POST') { $task = Get-AI5Task $Matches[1]; if (!$task) { Send-Json $stream @{ error = 'not_found' } 404; continue }; if ($task.status -ne 'waiting_approval') { Send-Json $stream @{ error = 'invalid_state' } 409; continue }; if(!$task.approval.contextComplete){Send-Json $stream @{error='APPROVAL_CONTEXT_INCOMPLETE';missing=@($task.approval.missingContext)} 409;continue};if($task.approval.ownerOperationRequired){Send-Json $stream @{error='owner_operation_required';message='本人にしかできない操作です'} 409;continue}; $body = Parse-Body $request; if (!(Use-AI5ApprovalToken $task.taskId $body.approvalToken)) { Write-AI5Log 'security' 'approval_rejected' @{ task_id = $task.taskId }; Send-Json $stream @{ error = 'invalid_approval_token' } 403; continue }; $receipt=Approve-AI5ApprovalRequest $task.taskId ([string]$session.login);$task.requiresApproval=$false;$task.approval.status = 'approved';$task.approval|Add-Member receiptId $receipt.receiptId -Force;$task|Add-Member approvalDecision (Save-AI5ApprovalDecision $task 'APPROVE' ([string]$session.login) $receipt.receiptId) -Force; Set-AI5TaskStatus $task 'RECEIVED' 'AI5 HUBで承認済み・自動再開'; Write-AI5Log 'security' 'approval' @{ task_id = $task.taskId; login = $session.login;receipt_id=$receipt.receiptId;auto_resume=$true }; Send-Json $stream $task; if($task.queue_reason){Set-AI5TaskStatus $task 'QUEUED' 'Writer解放後に承認済みTaskを自動再開'}else{Dispatch-Task $task}; continue }
            if ($path -match '^/api/tasks/([^/]+)/(cancel|reject)$' -and $method -eq 'POST') { $task = Get-AI5Task $Matches[1]; if (!$task) { Send-Json $stream @{ error = 'not_found' } 404; continue }; if ($task.status -in @('completed', 'failed', 'cancelled')) { Send-Json $stream @{ error = 'invalid_state' } 409; continue }; $approvalReceipt=$(if($task.status-eq'waiting_approval'){Reject-AI5ApprovalRequest $task.taskId ([string]$session.login)}else{$null});if($approvalReceipt){$task.approval.status='rejected';$task.approval|Add-Member receiptId $approvalReceipt.receiptId -Force;$task|Add-Member approvalDecision (Save-AI5ApprovalDecision $task 'REJECT' ([string]$session.login) $approvalReceipt.receiptId) -Force}; Update-State $task 'cancelled' 'Owner rejected this task only; global execution continues'; Write-AI5Log 'security' 'rejection' @{ task_id = $task.taskId; login = $session.login;global_state='EXECUTING' }; Send-Json $stream $task; Invoke-AI5QueuedTaskDispatch; continue }
            if ($path.StartsWith('/api/')) { Send-Json $stream @{ error = 'not_found' } 404 } else { Send-Static $stream $path }
        } catch {
            Write-AI5Log 'errors' 'request_failed' @{ error = $_.Exception.Message }
            try { Send-Json $stream @{ error = 'internal_error' } 500 } catch {}
        } finally {
            $stream.Dispose()
            $client.Dispose()
        }
    }
} finally {
    $listener.Stop()
}
