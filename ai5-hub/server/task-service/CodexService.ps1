function Initialize-AI5CodexService {
    param([string]$ServerRoot, [string]$AppRoot)
    $script:CodexServerRoot = $ServerRoot
    $script:CodexAppRoot = $AppRoot
    $script:CodexBridgeRoot = Join-Path $AppRoot 'integrations\codex\zero-codex-bridge'
    $script:CodexInbox = Join-Path $ServerRoot 'data\codex-inbox'
    $script:CodexRuntime = Join-Path $ServerRoot 'runtime'
    $script:CodexSecretPath = Join-Path $script:CodexRuntime 'bridge.secret'
    $script:CodexWorkerLock = Join-Path $script:CodexRuntime 'codex-worker.lock'
    $script:CodexWorkerScript = Join-Path $AppRoot 'server\task-service\CodexWorker.ps1'
    @($script:CodexInbox, $script:CodexRuntime) | ForEach-Object { New-Item -ItemType Directory -Force $_ | Out-Null }
    if (!(Test-Path $script:CodexSecretPath)) {
        $bytes = New-Object byte[] 32
        $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
        [Convert]::ToBase64String($bytes) | Set-Content -LiteralPath $script:CodexSecretPath -Encoding ASCII
    }
}

function Write-AI5Utf8Json {
    param($Value, [string]$Path, [int]$Depth = 8)
    $json = $Value | ConvertTo-Json -Depth $Depth
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

function Get-AI5CodexSignature {
    param([string]$TaskId, [string]$Instruction, [string]$ContextJson=$null)
    $key = [Convert]::FromBase64String((Get-Content -Raw $script:CodexSecretPath).Trim())
    $hmac = [Security.Cryptography.HMACSHA256]::new($key)
    try {
        $text=if($null-eq$ContextJson){"$TaskId`n$Instruction"}else{"$TaskId`n$Instruction`n$ContextJson"}
        $payload = [Text.Encoding]::UTF8.GetBytes($text)
        return [Convert]::ToBase64String($hmac.ComputeHash($payload))
    } finally { $hmac.Dispose() }
}

function Get-AI5CodexHealth {
    $disabled = $env:AI5_BRIDGE_DISABLED -eq 'true'
    $cachedCli = Join-Path $script:CodexBridgeRoot 'runtime\bin\codex.exe'
    $cliAvailable = (Test-Path $cachedCli) -or [bool](Get-Command codex -ErrorAction SilentlyContinue)
    $available = !$disabled -and $cliAvailable -and (Test-Path "$script:CodexBridgeRoot\bridge.ps1") -and (Test-Path $script:CodexWorkerScript)
    $connection = if ($disabled) { 'stopped' } elseif ($available) { 'official_cli' } else { 'not_connected' }
    return [ordered]@{ available = $available; connection = $connection; mode = 'live' }
}

function Get-AI5StoredCodexResult {
    param([string]$TaskId)
    if ($TaskId -notmatch '^AI5-[A-Za-z0-9_.-]+$') { return $null }
    try {
        $raw = & "$script:CodexBridgeRoot\bridge.ps1" show -TaskId $TaskId 2>$null
        if (!$raw) { return $null }
        return (($raw -join "`n") | ConvertFrom-Json)
    } catch { return $null }
}

function Get-AI5CodexInstruction {
    param($Task)
    $attachment=if($Task.attachment_id){Get-AI5AttachmentPath ([string]$Task.attachment_id)}else{$null}
    $agents = @($Task.assignedSecondary | Where-Object { $_ -and $_ -ne 'codex' } | Select-Object -Unique)
    if ($agents.Count -eq 0) { return (([string]$Task.message)+$(if($attachment){"`nAttached screenshot (read-only): $attachment"}else{''})) }
    $mode = if ($Task.execution_plan.mode) { [string]$Task.execution_plan.mode } else { 'sequential' }
    $specialists = $agents -join ', '
    $rules = @(
        (([string]$Task.message)+$(if($attachment){"`nAttached screenshot (read-only): $attachment"}else{''})),
        '',
        'AI5 ORCHESTRATION CONTRACT:',
        "- Required read-only specialists: $specialists",
        "- Execution mode: $mode. Run independent read-only checks concurrently when supported.",
        '- Claude: use the connected official Claude Code CLI in read-only mode.',
        '- Gemini: use only the connected logged-in Chrome route; never extract cookies, tokens, or credentials.',
        '- Manus: prefer the connected logged-in Chrome WEB route when READY; use the official Microsoft Store Windows app only as fallback after a verified WEB failure. Dispatch exactly once per task ID and never extract cookies, tokens, or credentials.',
        '- NotebookLM: read-only source lookup only, require citations, then verify current technical truth in GitHub.',
        '- Do not fabricate a specialist result. If a route is unavailable, record it as UNVERIFIED and continue with safe available evidence.',
        '- Codex is the single writer. No specialist may edit repository files.',
        '- Do not publish, purchase, contract, authenticate, or send data externally without an existing task-bound human approval.',
        '- Return each specialist result and Zero-integrated conclusion in the result schema evidence.'
    )
    return $rules -join "`n"
}

function Start-AI5CodexWorker {
    $health = Get-AI5CodexHealth
    if (!$health.available) { return $false }
    if (Test-Path $script:CodexWorkerLock) {
        $pidText = (Get-Content -Raw $script:CodexWorkerLock -ErrorAction SilentlyContinue).Trim()
        $process = $null
        if ($pidText -match '^\d+$') { $process = Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue }
        if ($process) { return $true }
        Remove-Item -LiteralPath $script:CodexWorkerLock -Force
    }
    'launching' | Set-Content -LiteralPath $script:CodexWorkerLock -Encoding ASCII
    try {
        $psi = [Diagnostics.ProcessStartInfo]::new()
        $pwsh = Join-Path $PSHOME 'pwsh.exe'
        $psi.FileName = if (Test-Path $pwsh) { $pwsh } else { "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" }
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:CodexWorkerScript`" -ServerRoot `"$script:CodexServerRoot`" -AppRoot `"$script:CodexAppRoot`" -UserHome `"$env:USERPROFILE`""
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
        $process = [Diagnostics.Process]::Start($psi)
        $process.Id | Set-Content -LiteralPath $script:CodexWorkerLock -Encoding ASCII
        return $true
    } catch {
        Remove-Item -LiteralPath $script:CodexWorkerLock -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Submit-AI5CodexTask {
    param($Task)
    if($Task.project_id-and(Get-Command Get-AI5ProjectExecutionContext -ErrorAction SilentlyContinue)){$Task|Add-Member -NotePropertyName projectContext -NotePropertyValue (Get-AI5ProjectExecutionContext ([string]$Task.project_id)) -Force;Save-AI5Task $Task}
    if(!$Task.projectContext){throw 'PROJECT_CONTEXT_MISSING: registered Project is required before Codex dispatch'}
    $instruction = Get-AI5CodexInstruction $Task
    $context = if($Task.projectContext){$Task.projectContext}else{$null}
    $contextJson = if($context){$context|ConvertTo-Json -Compress -Depth 10}else{''}
    $envelope = [ordered]@{
        task_id = $Task.taskId
        created_at = [DateTime]::UtcNow.ToString('o')
        source = 'ai5-hub'
        requested_by = $(if($context){'PROJECT_CONTROL'}else{'zero'})
        assigned_to = 'codex'
        instruction = $instruction
        risk_level = $Task.route.risk
        approval_required = $Task.requiresApproval
        status = 'queued'
        signature_version = 2
        project_context = $context
    }
    $envelope.signature = Get-AI5CodexSignature $envelope.task_id $envelope.instruction $contextJson
    $path = Join-Path $script:CodexInbox ($Task.taskId + '.json')
    if (Test-Path $path) { return [ordered]@{ accepted = $false; duplicate = $true; workerStarted = (Start-AI5CodexWorker) } }
    $temp = "$path.tmp"
    Write-AI5Utf8Json $envelope $temp 8
    Move-Item -LiteralPath $temp -Destination $path
    return [ordered]@{ accepted = $true; duplicate = $false; workerStarted = (Start-AI5CodexWorker) }
}
