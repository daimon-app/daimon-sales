param([int]$Port = 43125, [string]$HostName = '127.0.0.1')
$ErrorActionPreference = 'Stop'
if ($HostName -notin @('127.0.0.1','::1','localhost')) { throw 'AI5 HUB refuses non-loopback bind addresses' }
$ServerRoot = if ($global:AI5ServerRoot) { $global:AI5ServerRoot } else { $PSScriptRoot }
$AppRoot = Split-Path $ServerRoot

foreach ($module in @('router\Router.ps1', 'approval\ZeroApproval.ps1', 'approval\CapabilityPolicy.ps1', 'adapters\MockAdapter.ps1', 'storage\Store.ps1', 'source-of-truth\SourceOfTruth.ps1', 'evidence\EvidenceStore.ps1', 'security\Security.ps1', 'security\MobileSecurity.ps1', 'repository-lock\RepositoryLock.ps1', 'task-service\CodexService.ps1', 'orchestrator\TaskEngine.ps1', 'adapters\ClaudeAdapter.ps1', 'adapters\SpecialistRegistry.ps1', 'adapters\ExternalTaskAdapter.ps1', 'adapters\NotebookLMAdapter.ps1', 'project-control\ProjectControl.ps1', 'orchestrator\SalesFactory.ps1')) {
    . ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $ServerRoot $module))))
}
Initialize-AI5Store $ServerRoot
Recover-AI5RepositoryLocks (Join-Path $ServerRoot 'runtime')|Out-Null
Initialize-AI5MobileSecurity $ServerRoot
Initialize-AI5CodexService $ServerRoot $AppRoot
Initialize-AI5SpecialistRegistry $ServerRoot
Initialize-AI5ExternalTaskAdapter $ServerRoot
Initialize-AI5ProjectControl $ServerRoot $AppRoot
$script:AI5EvidenceAppRoot=(Join-Path $ServerRoot 'data')
Invoke-AI5ProjectRecovery
$Mock = if ($env:AI5_MOCK) { $env:AI5_MOCK -ne 'false' } else { $false }
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
    Update-State $task 'planning' 'Zero planning'
    Update-State $task 'running' "$($task.assignedPrimary) mock running"
    $task.result = Invoke-AI5MockAdapter $task
    Update-State $task 'reviewing' 'Zero reviewing'
    Update-State $task 'completed' 'Task completed'
    Write-AI5Log 'tasks' 'task_completed' @{ task_id = $task.taskId; status = 'completed'; adapter = 'mock' }
}

function Fail-Task($task, [string]$type, [string]$summary) {
    $task | Add-Member -NotePropertyName errorType -NotePropertyValue $type -Force
    $task.result = [ordered]@{ status = 'failed'; summary = $summary; details = @(); filesChanged = @(); tests = @(); warnings = @(); failureReason = $type; retryable = ($type -in @('bridge_unavailable', 'codex_unavailable', 'timeout')); userActionRequired = ($type -eq 'authentication_failed') }
    Update-State $task 'failed' $summary
}

function Finalize-AI5CodexResult($task) {
    if(!$task-or$task.assignedPrimary-ne'codex'){return $task}
    if($task.status-eq'reviewing'-and$task.result){$audit=Invoke-AI5ClaudeAdapter $task;$task.agent_results+=,$audit;$task.independent_audit=[ordered]@{status=$(if($audit.verdict-eq'PASS'){'PASS'}else{'FAIL'});ai='claude';evidence=@($audit.evidence);summary=$audit.summary};$task.validation=Test-AI5Completion $task;Exit-AI5TaskWriterLock $task;if($task.validation.passed){Set-AI5TaskStatus $task 'COMPLETED' 'Codex施工をClaude独立監査・Zero統合判定'}else{Set-AI5TaskStatus $task 'BLOCKED' 'Codex独立監査または受入証拠不足'}}elseif($task.status-eq'failed'){Exit-AI5TaskWriterLock $task};$task
}

function Dispatch-Task($task) {
    $policy=Test-AI5CapabilityPolicy $task
    if($policy.decision-eq'DENY'){Fail-Task $task 'invalid_operation' $policy.reason;return}
    if($policy.approvalRequired-and(!$task.approval-or$task.approval.status-ne'approved')){$task.requiresApproval=$true;Set-AI5TaskStatus $task 'WAITING_APPROVAL' $policy.reason;return}
    if($task.repository_path){try{$task.source_of_truth=Get-AI5SourceOfTruthSnapshot -RepositoryPath $task.repository_path -ExpectedBranch $task.branch -ExpectedHead $task.source_commit;Save-AI5Task $task;if($task.source_of_truth.branch_matches-eq$false-or$task.source_of_truth.head_matches-eq$false){throw'source_of_truth_mismatch'}}catch{$task.result=New-AI5Result $task.task_id $task.assigned_ai 'FAILED' $_.Exception.Message;$task.result.verdict='BLOCKED';$task.result.blockers=@('source_of_truth_failed');Set-AI5TaskStatus $task 'BLOCKED' 'GitHub正本復元失敗';return}}
    if ($Mock) { Execute-Mock $task; return }
    try{Enter-AI5TaskWriterLock $task (Join-Path $ServerRoot 'runtime')|Out-Null}catch{$task.result=New-AI5Result $task.task_id $task.assigned_ai 'FAILED' $_.Exception.Message;$task.result.verdict='BLOCKED';$task.result.blockers=@('writer_lock_failed');Set-AI5TaskStatus $task 'BLOCKED' 'Writer lock安全条件未達';return}
    if ($task.assignedPrimary -eq 'claude') { Set-AI5TaskStatus $task 'RUNNING' 'Claude施工・監査中';$task.attempt++;$task.retry_count=[Math]::Max(0,$task.attempt-1);$task.result=Invoke-AI5ClaudeAdapter $task;$task.agent_results+=,$task.result;Write-AI5Log 'tasks' 'claude_finished' @{task_id=$task.taskId;status=$task.result.status;summary=$task.result.summary;risks=$task.result.risks};Exit-AI5TaskWriterLock $task;if($task.result.status-eq'SUCCESS'){$task.independent_audit=[ordered]@{status='PENDING';ai='gemini';evidence=@()};Set-AI5TaskStatus $task 'BLOCKED' 'Claude施工物のGemini独立監査待ち'}else{$action=Get-AI5FailureAction $task 'complex_bug';if($action-eq'ESCALATED'){Set-AI5TaskStatus $task 'ESCALATED' 'retry上限到達'}else{$task.assignedPrimary='codex';$task.assigned_ai='codex';$task.assigned_agent='codex';$task.writer=$(if($task.repository_path){'codex'}else{'NONE'});Set-AI5TaskStatus $task 'RETRYING' 'Claude失敗のためCodexへFallback';Dispatch-Task $task}};return }
    if ($task.assignedPrimary -in @('gemini','manus')) { $task.attempt++;$task.retry_count=[Math]::Max(0,$task.attempt-1);Submit-AI5ExternalTask $task $task.assignedPrimary|Out-Null;Set-AI5TaskStatus $task 'RUNNING' "$($task.assignedPrimary)へ発行・Zero Return待ち";return }
    if ($task.assignedPrimary -ne 'codex') { Fail-Task $task 'adapter_unavailable' "$($task.assignedPrimary) adapter is not connected"; return }
    $health = Get-AI5CodexHealth
    if (!$health.available) { Exit-AI5TaskWriterLock $task;Fail-Task $task 'bridge_unavailable' 'Zero-Codex Bridge is unavailable'; return }
    try {
        $submitted = Submit-AI5CodexTask $task
        if (!$submitted.workerStarted) { Exit-AI5TaskWriterLock $task;Fail-Task $task 'bridge_unavailable' 'Codex worker could not start' }
    } catch {
        Write-AI5Log 'errors' 'bridge_submit_failed' @{ task_id = $task.taskId; error = $_.Exception.Message }
        Exit-AI5TaskWriterLock $task;Fail-Task $task 'bridge_unavailable' 'Zero-Codex Bridge submission failed'
    }
}

function Get-MobileHealth {
    $bridge = Get-AI5CodexHealth
    $worker = 'idle'
    $lockPath = Join-Path $ServerRoot 'runtime\codex-worker.lock'
    if (Test-Path $lockPath) {
        $pidText = (Get-Content -Raw $lockPath -ErrorAction SilentlyContinue).Trim()
        if ($pidText -match '^\d+$' -and (Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue)) { $worker = 'running' }
    }
    $tailscalePath = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    $tailscaleState = 'not_installed'
    if (Test-Path $tailscalePath) {
        try { $tailStatus = & $tailscalePath status --json 2>$null | ConvertFrom-Json; $tailscaleState = if ($tailStatus.BackendState -eq 'Running') { 'connected' } else { 'authentication_required' } } catch { $tailscaleState = 'error' }
    }
    return [ordered]@{ server = 'online'; localApi = 'online'; bridge = $(if ($bridge.available) { 'ready' } else { 'unavailable' }); codex = $(if ($bridge.available) { 'available' } else { 'unavailable' }); worker = $worker; remote = $tailscaleState }
}

function New-Task($body, [string]$idem) {
    $route = Get-AI5Route $body.message
    $id = if ($body.taskId) { $body.taskId } else { Get-AI5NextTaskId }
    $approval = if ($route.requiresApproval) { [ordered]@{ type = $route.approvalType; summary = '本人の最終承認が必要です'; status = 'pending'; zero_review = (Get-AI5ZeroApprovalReview $route) } } else { $null }
    $now=[DateTime]::UtcNow.ToString('o')
    $task=[pscustomobject][ordered]@{
        task_id=$id;taskId=$id;project_id=$(if($body.projectId){[string]$body.projectId}else{'unassigned'});product_id=$(if($body.productId){[string]$body.productId}else{'unassigned'});parent_task=$(if($body.parentTask){[string]$body.parentTask}else{$null});parent_task_id=$(if($body.parentTask){[string]$body.parentTask}else{$null});title=Protect-AI5Text $route.objective;conversationId=Protect-AI5Text([string]$body.conversationId);message=Protect-AI5Text $body.message;objective=Protect-AI5Text $route.objective;constraints=@(Protect-AI5Object $body.constraints)
        source = $(if ($body.source) { Protect-AI5Text([string]$body.source) } else { 'teppei' }); priority = $(if ($body.priority) { $body.priority } else { 'normal' })
        assigned_agent=$route.primary;status = $(if ($route.requiresApproval) { 'waiting_approval' } else { 'queued' });canonical_status=$(if ($route.requiresApproval){'WAITING_APPROVAL'}else{'RECEIVED'});approval_level=$(if($route.requiresApproval){'RED'}elseif($route.risk-eq'medium'){'YELLOW'}else{'GREEN'});attempt=0;max_attempts=3;assignedPrimary = $route.primary; assignedSecondary = $route.secondary
        requiresApproval = $route.requiresApproval; approval = $approval; field_mode=$(if($null-ne$body.fieldMode){[bool]$body.fieldMode}else{$true}); route = $route; validation=[ordered]@{};artifacts=@();result = $null
        timeline = @([ordered]@{ status = 'RECEIVED'; label = '依頼受付'; at = $now })
        children=@();idempotencyKey = $idem; created_at=$now;updated_at=$now;createdAt = $now; updatedAt = $now
    }
    $task=Initialize-AI5TaskV6Fields $task $body $route
    $task.children=New-AI5Children $task $route
    return $task
}

try {
    while ($true) {
        if(!$listener.Pending()){
            $scheduler=Get-AI5SchedulerStatus
            $due=!$scheduler.nextScan-or([DateTimeOffset]::Parse($scheduler.nextScan)-le[DateTimeOffset]::Now)
            if($due-and!$Mock-and$env:AI5_DISABLE_SCHEDULER-ne'true'){try{Invoke-AI5ProjectScan -Fetch $true|Out-Null}catch{Write-AI5Log 'errors' 'project_scheduler_failed' @{error=$_.Exception.Message}}}
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
            if($path.StartsWith('/api/')){Write-AI5Log 'tasks' 'api_request' @{method=$method;path=$path}}
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
            if ($method -eq 'GET' -and $path -eq '/api/health') { Send-Json $stream @{ ok = $true; service = 'ai5-hub'; mock = $Mock; csrfToken = $Csrf; components = (Get-MobileHealth); time = [DateTime]::UtcNow.ToString('o') }; continue }
            if ($method -eq 'GET' -and $path -eq '/api/status') {
                $bridgeHealth = Get-AI5CodexHealth
                $claudeHealth = Get-AI5ClaudeHealth
                $geminiHealth = Get-AI5SpecialistHealth 'gemini'
                $manusHealth = Get-AI5SpecialistHealth 'manus'
                $codexState = if ($Mock -or $bridgeHealth.available) { 'ready' } else { 'offline' }
                $codexConnection = if ($Mock) { 'mock' } elseif ($bridgeHealth.available) { 'official_cli' } else { 'not_connected' }
                Send-Json $stream @{ mode = $(if ($Mock) { 'mock' } else { 'live' }); bridge = $bridgeHealth; agents = @{ zero = @{ state = 'ready'; connection = 'local' }; codex = @{ state = $codexState; connection = $codexConnection }; gemini = @{ state = $(if ($Mock -or $geminiHealth.available) { 'ready' } else { 'offline' }); connection = $(if ($Mock) { 'mock' } else { $geminiHealth.connection });quota=$geminiHealth.quota }; claude = @{ state = $(if ($Mock -or $claudeHealth.available) { 'ready' } else { 'offline' }); connection = $(if ($Mock) { 'mock' } else { $claudeHealth.connection });quota=$claudeHealth.quota }; manus = @{ state = $(if ($Mock -or $manusHealth.available) { 'ready' } else { 'offline' }); connection = $(if ($Mock) { 'mock' } else { $manusHealth.connection });quota=$manusHealth.quota } }; tasks = @(Get-AI5Tasks) }
                continue
            }
            if ($method -eq 'GET' -and $path -eq '/api/projects') { Send-Json $stream (Get-AI5ProjectSummary); continue }
            if ($method -eq 'GET' -and $path -eq '/api/sales-factory') { Send-Json $stream @{factory=Get-Content -Raw -Encoding UTF8 (Join-Path $AppRoot 'project-control\sales-factory-v6.json')|ConvertFrom-Json;projects=@(Get-AI5SalesFactoryProjects)};continue }
            if ($method -eq 'POST' -and $path -eq '/api/sales-factory/start') { $body=Parse-Body $request;Send-Json $stream (Start-AI5SalesFactory -DryRun ($body.dryRun-ne$false)) 202;continue }
            if ($method -eq 'POST' -and $path -eq '/api/projects') { $body=Parse-Body $request; if(!$body.name-or!$body.projectId){Send-Json $stream @{error='name_and_project_id_required'} 400;continue}; try{Send-Json $stream (New-AI5Project $body) 202}catch{Send-Json $stream @{error=$_.Exception.Message} 409}; continue }
            if ($method -eq 'GET' -and $path -eq '/api/projects/repositories') { Send-Json $stream @{repositories=@(Get-AI5RepositoryCandidates)};continue }
            if ($path -match '^/api/projects/(?!(system|repositories)$)([^/]+)$' -and $method -eq 'GET') { try{$project=Get-AI5Project $Matches[2]}catch{$project=$null};if($project){Send-Json $stream $project}else{Send-Json $stream @{error='not_found'} 404};continue }
            if ($path -match '^/api/projects/([^/]+)/state$' -and $method -eq 'POST') { $project=Get-AI5Project $Matches[1];if(!$project){Send-Json $stream @{error='not_found'} 404;continue};Send-Json $stream (Set-AI5ProjectState $project (Parse-Body $request) 'TEPPEI');continue }
            if ($path -match '^/api/projects/([^/]+)/auto-execution$' -and $method -eq 'POST') { $project=Get-AI5Project $Matches[1];if(!$project){Send-Json $stream @{error='not_found'} 404;continue};$body=Parse-Body $request;$mode=if($body.mode){[string]$body.mode}elseif([bool]$body.enabled){'DRY_RUN'}else{'OFF'};try{Send-Json $stream (Set-AI5ProjectAuto $project $mode)}catch{Send-Json $stream @{error=$_.Exception.Message} 400};continue }
            if ($path -match '^/api/projects/([^/]+)/execution-check$' -and $method -eq 'GET') { $project=Get-AI5Project $Matches[1];if(!$project){Send-Json $stream @{error='not_found'} 404}else{Send-Json $stream (Test-AI5ProjectExecution $project)};continue }
            if ($method -eq 'POST' -and $path -eq '/api/projects/scan') { $body=Parse-Body $request;Send-Json $stream (Invoke-AI5ProjectScan -Fetch ($body.fetch-ne$false) -DryRun ([bool]$body.dryRun));continue }
            if ($method -eq 'GET' -and $path -eq '/api/projects/system') { $projects=@(Get-AI5Projects);$locks=@(Get-AI5ActiveLocks);$bridge=Get-AI5CodexHealth;Send-Json $stream @{scheduler=Get-AI5SchedulerStatus;bridge=$bridge;locks=$locks;queue=@(Get-ChildItem (Join-Path $ServerRoot 'data\codex-inbox') -Filter '*.json' -ErrorAction SilentlyContinue).Count;autoLive=@($projects|Where-Object{$_.autoExecution.mode-eq'LIVE'}).Count;dryRun=@($projects|Where-Object{$_.autoExecution.mode-eq'DRY_RUN'}).Count;creditStops=@($projects|Where-Object{$_.stopCode-eq'CREDIT_PROTECTION_STOP'}).Count;approvalStops=@($projects|Where-Object{$_.status-eq'APPROVAL_REQUIRED'}).Count};continue }
            if ($path -match '^/api/projects/([^/]+)/sync$' -and $method -eq 'POST') { $project=Get-AI5Project $Matches[1];if(!$project){Send-Json $stream @{error='not_found'} 404}else{Send-Json $stream (Sync-AI5ProjectGit $project)};continue }
            if ($method -eq 'POST' -and $path -eq '/api/tasks') {
                $body = Parse-Body $request
                $capabilityPolicy=Test-AI5CapabilityPolicy $body
                if($capabilityPolicy.decision-eq'DENY'){Send-Json $stream @{error=$capabilityPolicy.reason} 400;continue}
                $problem = Test-AI5Instruction $body.message
                if ($problem) { Send-Json $stream @{ error = $problem } 400; continue }
                if ($body.taskId -and $body.taskId -notmatch '^task_[A-Za-z0-9_.-]{3,80}$') { Send-Json $stream @{ error = 'invalid_task_id' } 400; continue }
                if ($body.taskId) { $same = Get-AI5Task $body.taskId; if ($same) { Send-Json $stream $same; continue } }
                $idem = $request.Headers['Idempotency-Key']
                if ($idem) { $existing=Find-AI5TaskByIdempotencyKey $idem;if($existing){$incomingHash=Get-AI5PayloadHash([string]$body.message);if($existing.payload_hash-and$existing.payload_hash-ne$incomingHash){Send-Json $stream @{error='idempotency_key_payload_conflict'} 409;continue};Send-Json $stream $existing;continue} }
                $task = New-Task $body $idem
                if($capabilityPolicy.approvalRequired){$task.operation=$capabilityPolicy.operation;$task.requiresApproval=$true;$task.status='waiting_approval';$task.canonical_status='WAITING_APPROVAL';$task.approval=[ordered]@{type=$capabilityPolicy.capability;summary='本人の最終承認が必要です';status='pending';zero_review=[ordered]@{verdict='APPROVAL_OK';reason=$capabilityPolicy.reason;risks=@($capabilityPolicy.capability);checks=@('typed capability policy')}}}
                if ($task.requiresApproval) { $task.timeline += , [ordered]@{ status = 'WAITING_APPROVAL'; label = '本人承認待ち'; at = [DateTime]::UtcNow.ToString('o') } }
                Save-AI5Task $task
                Write-AI5Log 'tasks' 'task_created' @{ task_id = $task.taskId; primary = $task.assignedPrimary; approval = $task.requiresApproval }
                Send-Json $stream $task 202
                if (!$task.requiresApproval) { Dispatch-Task $task }
                continue
            }
            if ($method -eq 'GET' -and $path -eq '/api/tasks') { Send-Json $stream @{ tasks=@(Get-AI5Tasks 100) }; continue }
            if ($path -match '^/api/agents/(manus|gemini)/outbox$' -and $method -eq 'GET') { $agent=$Matches[1];$items=@(Get-AI5ExternalOutbox $agent|ForEach-Object{[ordered]@{task_id=$_.task_id;project_id=$_.project_id;product_id=$_.product_id;assigned_ai=$_.assigned_ai;created_at=$_.created_at}});Send-Json $stream @{agent=$agent;tasks=$items;result_tokens='internal_bridge_only'};continue }
            if ($path -match '^/api/tasks/([^/]+)$' -and $method -eq 'GET') { $task = Get-AI5Task $Matches[1]; if ($task -and !$Mock -and $task.assignedPrimary -eq 'codex' -and $task.status -in @('queued', 'running')) { Start-AI5CodexWorker | Out-Null };if($task-and$task.assignedPrimary-eq'codex'-and$task.status-in@('reviewing','failed')){$task=Finalize-AI5CodexResult $task}; if ($task) { Send-Json $stream $task } else { Send-Json $stream @{ error = 'not_found' } 404 }; continue }
            if ($path -match '^/api/tasks/([^/]+)/result$' -and $method -eq 'GET') { $task = Get-AI5Task $Matches[1]; if (!$task) { Send-Json $stream @{ error = 'not_found' } 404 } elseif ($task.result) { Send-Json $stream @{ taskId = $task.taskId; status = $task.status; result = $task.result; bridge = $task.bridge } } else { Send-Json $stream @{ taskId = $task.taskId; status = $task.status; result = $null } 202 }; continue }
            if ($path -match '^/api/tasks/([^/]+)/result$' -and $method -eq 'POST') { $task=Get-AI5Task $Matches[1];if(!$task){Send-Json $stream @{error='not_found'} 404;continue};if($task.status-notin@('running','reviewing','blocked')){Send-Json $stream @{error='invalid_state'} 409;continue};try{$task=Receive-AI5ExternalResult $task (Parse-Body $request);Write-AI5Log 'tasks' 'zero_return_collected' @{task_id=$task.taskId;ai=$task.result.ai;verdict=$task.result.verdict};Send-Json $stream $task 202}catch{Write-AI5Log 'security' 'result_rejected' @{task_id=$task.taskId;error=$_.Exception.Message};Send-Json $stream @{error=$_.Exception.Message} 400};continue }
            if ($path -match '^/api/tasks/([^/]+)/approval-challenge$' -and $method -eq 'POST') { $task=Get-AI5Task $Matches[1];if(!$task){Send-Json $stream @{error='not_found'} 404;continue};if($task.status-ne'waiting_approval'){Send-Json $stream @{error='invalid_state'} 409;continue};Write-AI5Log 'security' 'approval_challenge_created' @{task_id=$task.taskId;login=$session.login};Send-Json $stream @{approvalToken=(New-AI5ApprovalToken $task.taskId);expiresInSeconds=300};continue }
            if ($path -match '^/api/tasks/([^/]+)/approve$' -and $method -eq 'POST') { $task = Get-AI5Task $Matches[1]; if (!$task) { Send-Json $stream @{ error = 'not_found' } 404; continue }; if ($task.status -ne 'waiting_approval') { Send-Json $stream @{ error = 'invalid_state' } 409; continue }; $body = Parse-Body $request; if (!(Use-AI5ApprovalToken $task.taskId $body.approvalToken)) { Write-AI5Log 'security' 'approval_rejected' @{ task_id = $task.taskId }; Send-Json $stream @{ error = 'invalid_approval_token' } 403; continue }; $task.approval.status = 'approved'; Set-AI5TaskStatus $task 'RECEIVED' '本人承認済み'; Write-AI5Log 'security' 'approval' @{ task_id = $task.taskId; login = $session.login }; Send-Json $stream $task; Dispatch-Task $task; continue }
            if ($path -match '^/api/tasks/([^/]+)/(cancel|reject)$' -and $method -eq 'POST') { $task = Get-AI5Task $Matches[1]; if (!$task) { Send-Json $stream @{ error = 'not_found' } 404; continue }; if ($task.status -in @('completed', 'failed', 'cancelled')) { Send-Json $stream @{ error = 'invalid_state' } 409; continue }; Update-State $task 'cancelled' 'User rejected'; Write-AI5Log 'security' 'rejection' @{ task_id = $task.taskId; login = $session.login }; Send-Json $stream $task; continue }
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
