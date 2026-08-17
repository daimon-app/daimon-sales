param([int]$Port = 43125, [string]$HostName = '127.0.0.1')
$ErrorActionPreference = 'Stop'
$ServerRoot = if ($global:AI5ServerRoot) { $global:AI5ServerRoot } else { $PSScriptRoot }
$AppRoot = Split-Path $ServerRoot

foreach ($module in @('router\Router.ps1', 'adapters\MockAdapter.ps1', 'storage\Store.ps1', 'security\Security.ps1', 'security\MobileSecurity.ps1', 'task-service\CodexService.ps1')) {
    . ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $ServerRoot $module))))
}
Initialize-AI5Store $ServerRoot
Initialize-AI5MobileSecurity $ServerRoot
Initialize-AI5CodexService $ServerRoot $AppRoot
$Mock = if ($env:AI5_MOCK) { $env:AI5_MOCK -ne 'false' } else { $false }
$Csrf = [guid]::NewGuid().ToString('N')
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Parse($HostName), $Port)
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
    $types = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8'; '.json' = 'application/json; charset=utf-8'; '.webmanifest' = 'application/manifest+json; charset=utf-8'; '.svg' = 'image/svg+xml' }
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

function Dispatch-Task($task) {
    if ($Mock) { Execute-Mock $task; return }
    if ($task.assignedPrimary -ne 'codex') { Fail-Task $task 'adapter_unavailable' "$($task.assignedPrimary) adapter is not connected"; return }
    $health = Get-AI5CodexHealth
    if (!$health.available) { Fail-Task $task 'bridge_unavailable' 'Zero-Codex Bridge is unavailable'; return }
    try {
        $submitted = Submit-AI5CodexTask $task
        if (!$submitted.workerStarted) { Fail-Task $task 'bridge_unavailable' 'Codex worker could not start' }
    } catch {
        Write-AI5Log 'errors' 'bridge_submit_failed' @{ task_id = $task.taskId; error = $_.Exception.Message }
        Fail-Task $task 'bridge_unavailable' 'Zero-Codex Bridge submission failed'
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
    $id = if ($body.taskId) { $body.taskId } else { 'task_' + [guid]::NewGuid().ToString('N').Substring(0, 12) }
    $approval = if ($route.requiresApproval) { [ordered]@{ type = $route.approvalType; summary = 'User approval required'; status = 'pending' } } else { $null }
    return [pscustomobject][ordered]@{
        taskId = $id; conversationId = $body.conversationId; message = Protect-AI5Text $body.message; objective = $route.objective
        source = $(if ($body.source) { $body.source } else { 'teppei' }); priority = $(if ($body.priority) { $body.priority } else { 'normal' })
        status = $(if ($route.requiresApproval) { 'waiting_approval' } else { 'queued' }); assignedPrimary = $route.primary; assignedSecondary = $route.secondary
        requiresApproval = $route.requiresApproval; approval = $approval; route = $route; result = $null
        timeline = @([ordered]@{ status = 'queued'; label = 'Local API accepted'; at = [DateTime]::UtcNow.ToString('o') })
        idempotencyKey = $idem; createdAt = [DateTime]::UtcNow.ToString('o'); updatedAt = [DateTime]::UtcNow.ToString('o')
    }
}

try {
    while ($true) {
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
            if ($method -eq 'GET' -and $path -eq '/api/health') { Send-Json $stream @{ ok = $true; service = 'ai5-hub'; mock = $Mock; csrfToken = $Csrf; components = (Get-MobileHealth); time = [DateTime]::UtcNow.ToString('o') }; continue }
            if ($method -eq 'GET' -and $path -eq '/api/status') {
                $bridgeHealth = Get-AI5CodexHealth
                $codexState = if ($Mock -or $bridgeHealth.available) { 'ready' } else { 'offline' }
                $codexConnection = if ($Mock) { 'mock' } elseif ($bridgeHealth.available) { 'official_cli' } else { 'not_connected' }
                Send-Json $stream @{ mode = $(if ($Mock) { 'mock' } else { 'live' }); bridge = $bridgeHealth; agents = @{ zero = @{ state = 'ready'; connection = 'local' }; codex = @{ state = $codexState; connection = $codexConnection }; gemini = @{ state = $(if ($Mock) { 'ready' } else { 'offline' }); connection = $(if ($Mock) { 'mock' } else { 'not_connected' }) }; claude = @{ state = $(if ($Mock) { 'ready' } else { 'offline' }); connection = $(if ($Mock) { 'mock' } else { 'not_connected' }) }; manus = @{ state = $(if ($Mock) { 'ready' } else { 'offline' }); connection = $(if ($Mock) { 'mock' } else { 'not_connected' }) } }; tasks = @(Get-AI5Tasks) }
                continue
            }
            if ($method -eq 'POST' -and $path -eq '/api/tasks') {
                $body = Parse-Body $request
                $problem = Test-AI5Instruction $body.message
                if ($problem) { Send-Json $stream @{ error = $problem } 400; continue }
                if ($body.taskId -and $body.taskId -notmatch '^task_[A-Za-z0-9_.-]{3,80}$') { Send-Json $stream @{ error = 'invalid_task_id' } 400; continue }
                if ($body.taskId) { $same = Get-AI5Task $body.taskId; if ($same) { Send-Json $stream $same; continue } }
                $idem = $request.Headers['Idempotency-Key']
                if ($idem) { $existing = Get-AI5Tasks | Where-Object { $_.idempotencyKey -eq $idem } | Select-Object -First 1; if ($existing) { Send-Json $stream $existing; continue } }
                $task = New-Task $body $idem
                if ($task.requiresApproval) { $task.timeline += , [ordered]@{ status = 'waiting_approval'; label = 'Waiting for user approval'; at = [DateTime]::UtcNow.ToString('o') } }
                Save-AI5Task $task
                Write-AI5Log 'tasks' 'task_created' @{ task_id = $task.taskId; primary = $task.assignedPrimary; approval = $task.requiresApproval }
                if ($task.requiresApproval) { $task | Add-Member -NotePropertyName approvalToken -NotePropertyValue (New-AI5ApprovalToken $task.taskId) -Force }
                Send-Json $stream $task 202
                if (!$task.requiresApproval) { Dispatch-Task $task }
                continue
            }
            if ($path -match '^/api/tasks/([^/]+)$' -and $method -eq 'GET') { $task = Get-AI5Task $Matches[1]; if ($task -and !$Mock -and $task.assignedPrimary -eq 'codex' -and $task.status -in @('queued', 'running')) { Start-AI5CodexWorker | Out-Null }; if ($task) { if ($task.status -eq 'waiting_approval') { $task | Add-Member -NotePropertyName approvalToken -NotePropertyValue (New-AI5ApprovalToken $task.taskId) -Force }; Send-Json $stream $task } else { Send-Json $stream @{ error = 'not_found' } 404 }; continue }
            if ($path -match '^/api/tasks/([^/]+)/result$' -and $method -eq 'GET') { $task = Get-AI5Task $Matches[1]; if (!$task) { Send-Json $stream @{ error = 'not_found' } 404 } elseif ($task.result) { Send-Json $stream @{ taskId = $task.taskId; status = $task.status; result = $task.result; bridge = $task.bridge } } else { Send-Json $stream @{ taskId = $task.taskId; status = $task.status; result = $null } 202 }; continue }
            if ($path -match '^/api/tasks/([^/]+)/approve$' -and $method -eq 'POST') { $task = Get-AI5Task $Matches[1]; if (!$task) { Send-Json $stream @{ error = 'not_found' } 404; continue }; if ($task.status -ne 'waiting_approval') { Send-Json $stream @{ error = 'invalid_state' } 409; continue }; $body = Parse-Body $request; if (!(Use-AI5ApprovalToken $task.taskId $body.approvalToken)) { Write-AI5Log 'security' 'approval_rejected' @{ task_id = $task.taskId }; Send-Json $stream @{ error = 'invalid_approval_token' } 403; continue }; $task.approval.status = 'approved'; Update-State $task 'queued' 'User approved'; Write-AI5Log 'security' 'approval' @{ task_id = $task.taskId; login = $session.login }; Send-Json $stream $task; Dispatch-Task $task; continue }
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
