param(
    [Parameter(Mandatory = $true)][string]$ServerRoot,
    [Parameter(Mandatory = $true)][string]$AppRoot,
    [string]$UserHome
)

$ErrorActionPreference = 'Stop'
if ($UserHome) {
    $env:USERPROFILE = $UserHome
    $env:CODEX_HOME = Join-Path $UserHome '.codex'
}
$bridge = Join-Path $AppRoot 'integrations\codex\zero-codex-bridge'
$inbox = Join-Path $ServerRoot 'data\codex-inbox'
$secretPath = Join-Path $ServerRoot 'runtime\bridge.secret'
$workerLock = Join-Path $ServerRoot 'runtime\codex-worker.lock'
$taskRoot = Join-Path $ServerRoot 'data\tasks'
$logRoot = Join-Path $ServerRoot 'logs\tasks'
New-Item -ItemType Directory -Force $logRoot | Out-Null
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $AppRoot 'server\notifications\PushNotification.ps1'))))
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $AppRoot 'server\orchestrator\AutonomousLoop.ps1'))))
Initialize-AI5PushNotifications $ServerRoot $AppRoot

function Read-Utf8Json([string]$path) {
    return [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
}

function Write-Utf8Json($value, [string]$path, [int]$depth = 15) {
    $json = $value | ConvertTo-Json -Depth $depth
    [IO.File]::WriteAllText($path, $json, [Text.UTF8Encoding]::new($false))
}

function Resolve-ProjectWorkspace($context) {
    if (!$context -or !$context.projectId) { throw 'PROJECT_CONTEXT_MISSING: Codex requires a registered Project and canonical worktree' }
    $repository = [string]$context.repository
    if ($repository -notmatch '^[A-Za-z0-9_.-]{2,100}$') { throw 'Invalid project repository name' }
    $candidate = if($context.worktreePath){[string]$context.worktreePath}elseif($context.repositoryPath){[string]$context.repositoryPath}else{throw 'PROJECT_CONTEXT_MISSING: canonical worktree is absent'}
    $candidate = [IO.Path]::GetFullPath($candidate)
    $allowedRoot = [IO.Path]::GetFullPath((Join-Path $UserHome 'Documents\GitHub')).TrimEnd('\') + '\'
    if (!$candidate.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase) -or !(Test-Path $candidate)) { throw 'UNTRUSTED_WORKDIR: canonical worktree is outside the repository allowlist or missing' }
    $gitRoot=((& git -C $candidate rev-parse --show-toplevel 2>$null)-join'').Trim();if(!$gitRoot){throw'UNTRUSTED_WORKDIR: git root unavailable'};$gitRoot=[IO.Path]::GetFullPath($gitRoot)
    if($gitRoot-ne$candidate-or($context.gitRoot-and[IO.Path]::GetFullPath([string]$context.gitRoot)-ne$gitRoot)){throw'UNTRUSTED_WORKDIR: canonical worktree and git root do not match'}
    $origin=((& git -C $gitRoot remote get-url origin 2>$null)-join'').Trim();if(!$origin-or$origin-notmatch('[/:]'+[regex]::Escape($repository)+'(?:\.git)?$')){throw'UNTRUSTED_WORKDIR: repository origin does not match signed Project context'}
    $branch = (& git -C $candidate branch --show-current 2>$null) -join ''
    if (!$branch -or ($context.branch -and $branch -ne [string]$context.branch)) { throw 'Project workspace branch does not match signed context' }
    $head=((& git -C $candidate rev-parse HEAD 2>$null)-join'').Trim();$status=@(& git -C $candidate status --short 2>$null)
    [pscustomobject]@{path=$candidate;gitRoot=$gitRoot;branch=$branch;head=$head;status=$status;trusted=$true;repository=$repository;projectId=[string]$context.projectId}
}

function Get-Signature($id, $instruction, [string]$contextJson=$null) {
    $key = [Convert]::FromBase64String((Get-Content -Raw $secretPath).Trim())
    $hmac = [Security.Cryptography.HMACSHA256]::new($key)
    try {
        $text=if($null-eq$contextJson){"$id`n$instruction"}else{"$id`n$instruction`n$contextJson"}
        $payload = [Text.Encoding]::UTF8.GetBytes($text)
        return [Convert]::ToBase64String($hmac.ComputeHash($payload))
    } finally {
        $hmac.Dispose()
    }
}

function Save-Task($task, $path) {
    $task.updatedAt = [DateTime]::UtcNow.ToString('o')
    $temp = "$path.tmp"
    Write-Utf8Json $task $temp 15
    Move-Item -LiteralPath $temp -Destination $path -Force
}

function Set-TaskProperty($task, $name, $value) {
    $task | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force
}

function Set-TaskState($task, $path, $status, $label) {
    $task.status = $status
    $canonical = @{ queued='RECEIVED'; planning='PLANNING'; running='RUNNING'; reviewing='VALIDATING'; retrying='RETRYING'; waiting_approval='WAITING_APPROVAL'; completed='COMPLETED'; failed='FAILED'; cancelled='CANCELLED' }[$status]
    Set-TaskProperty $task 'canonical_status' $canonical
    $task.timeline += , [ordered]@{
        status = $status
        label = $label
        at = [DateTime]::UtcNow.ToString('o')
    }
    Save-Task $task $path
}

function Write-WorkerLog($eventName, $fields) {
    $item = [ordered]@{
        timestamp = [DateTime]::UtcNow.ToString('o')
        event = $eventName
    }
    foreach ($key in $fields.Keys) {
        $item[$key] = $fields[$key]
    }
    $logPath = Join-Path $logRoot ((Get-Date).ToString('yyyy-MM-dd') + '.jsonl')
    Add-Content -LiteralPath $logPath -Encoding UTF8 -Value ($item | ConvertTo-Json -Compress -Depth 8)
}

$currentTask = $null
$currentTaskPath = $null
$currentEnvelopePath = $null

try {
    $idlePasses = 0
    while ($idlePasses -lt 2) {
        $file = Get-ChildItem $inbox -Filter '*.json' | Sort-Object CreationTime | Select-Object -First 1
        if (!$file) {
            $idlePasses++
            Start-Sleep -Milliseconds 350
            continue
        }

        $idlePasses = 0
        $currentEnvelopePath = $file.FullName
        $envelope = Read-Utf8Json $file.FullName
        $currentTaskPath = Join-Path $taskRoot ($envelope.task_id + '.json')
        if (!(Test-Path $currentTaskPath)) {
            Remove-Item -LiteralPath $file.FullName -Force
            continue
        }

        $currentTask = Read-Utf8Json $currentTaskPath
        if ($currentTask.status -in @('completed','failed','cancelled')) {
            Write-WorkerLog 'terminal_envelope_discarded' @{ task_id = $currentTask.taskId; status = $currentTask.status }
            Remove-Item -LiteralPath $file.FullName -Force
            $currentTask = $null
            $currentTaskPath = $null
            $currentEnvelopePath = $null
            continue
        }
        Set-TaskProperty $currentTask 'attempt' ([int]$currentTask.attempt + 1)
        $contextJson = if($envelope.signature_version-eq2){if($envelope.project_context){$envelope.project_context|ConvertTo-Json -Compress -Depth 10}else{''}}else{$null}
        $expected = Get-Signature $envelope.task_id $envelope.instruction $contextJson
        if ($envelope.signature -ne $expected) {
            Set-TaskProperty $currentTask 'errorType' 'authentication_failed'
            $currentTask.result = [ordered]@{
                status = 'failed'
                summary = 'Bridge authentication failed'
                details = @()
                filesChanged = @()
                tests = @()
                warnings = @()
                failureReason = 'authentication_failed'
                retryable = $false
                userActionRequired = $false
            }
            Set-TaskState $currentTask $currentTaskPath 'failed' 'Bridge authentication rejected'
            Write-WorkerLog 'codex_auth_failed' @{ task_id = $currentTask.taskId }
            Remove-Item -LiteralPath $file.FullName -Force
            $currentTask = $null
            continue
        }

        Set-TaskState $currentTask $currentTaskPath 'planning' 'Zero prepared a structured Codex instruction'
        Set-TaskState $currentTask $currentTaskPath 'running' 'Codex execution started'

        $preflight = Resolve-ProjectWorkspace $envelope.project_context
        Set-TaskProperty $currentTask 'worktree_preflight' ([ordered]@{projectId=$preflight.projectId;repository=$preflight.repository;expectedWorktree=[string]$envelope.project_context.worktreePath;actualCwd=$preflight.path;gitRoot=$preflight.gitRoot;branch=$preflight.branch;head=$preflight.head;gitStatus=@($preflight.status);trusted=$preflight.trusted;checkedAt=[DateTime]::UtcNow.ToString('o')})
        Save-Task $currentTask $currentTaskPath;Write-WorkerLog 'codex_worktree_preflight_passed' $currentTask.worktree_preflight
        $workspace = $preflight.path
        & "$bridge\bridge.ps1" enqueue -TaskId $envelope.task_id -Instruction $envelope.instruction -Workspace $workspace | Out-Null
        $result = & "$bridge\bridge.ps1" run-once | ConvertFrom-Json
        if (!$result -or $result.task_id -ne $envelope.task_id) {
            $result = & "$bridge\bridge.ps1" show -TaskId $envelope.task_id | ConvertFrom-Json
        }

        Set-TaskProperty $currentTask 'bridge' ([ordered]@{
            taskId = $result.task_id
            status = $result.status
            sessionId = $result.codex_session_id
            attemptCount = $result.attempt_count
            startedAt = $result.started_at
            finishedAt = $result.finished_at
        })
        $summary = if ($result.result) { $result.result } else { 'Codex task failed' }
        $currentTask.result = [ordered]@{
            task_id = $currentTask.taskId
            agent = 'codex'
            status = $result.status
            summary = $summary
            details = @($result.details)
            filesChanged = @($result.files_changed)
            tests = @($result.tests)
            warnings = @($result.warnings)
            commitId = $result.commit_id
            failureReason = $result.error
            retryable = [bool]$result.retryable
            userActionRequired = [bool]$result.human_action_required
            findings = @($result.details)
            changes = @($result.files_changed)
            artifacts = @($result.files_changed)
            risks = @($result.warnings)
            next_action = $(if($result.status-eq'success'){'VALIDATE'}elseif($result.retryable){'RETRY'}else{'ESCALATE_ZERO'})
            needs_human = [bool]$result.human_action_required
            human_reason = $(if($result.human_action_required){$result.error}else{$null})
        }

        if ($result.status -eq 'success') {
            Set-TaskState $currentTask $currentTaskPath 'reviewing' 'Bridge collected Codex evidence'
            Set-TaskProperty $currentTask 'validation' ([ordered]@{passed=$true;checks=[ordered]@{result_schema=$true;tests=(@($result.tests).Count-gt 0);bridge_success=$true};checked_at=[DateTime]::UtcNow.ToString('o')})
            $null=Initialize-AI5LoopTask $currentTask
            Add-AI5AgentReport $currentTask 'codex' 'COMPLETE' '現物確認・施工・検査' $summary ($(if(@($result.warnings).Count){@($result.warnings)-join' / '}else{'なし'})) 'Zero統合監査'
            foreach($specialist in @($currentTask.assignedSecondary|Where-Object{$_-and$_-ne'codex'})){
                $found=@($currentTask.agent_results|Where-Object{$_.agent-eq$specialist}|Select-Object -First 1)
                if($found.Count){Add-AI5AgentReport $currentTask $specialist ([string]$found[0].status) '専門領域を確認' ([string]$found[0].summary) (@($found[0].risks)-join' / ') 'Zero統合監査'}
                elseif($summary-match("(?im)^-\s*"+[regex]::Escape($specialist)+"\s*:\s*(VERIFIED|PARTIALLY VERIFIED|PASS|SUCCESS|UNVERIFIED)")){$specialistState=if($Matches[1]-eq'UNVERIFIED'){'BLOCKED'}else{'COMPLETE'};Add-AI5AgentReport $currentTask $specialist $specialistState '専門経路を実行' $Matches[1] $(if($specialistState-eq'BLOCKED'){'UNVERIFIED'}else{'なし'}) 'Zero統合監査'}
                else{Add-AI5AgentReport $currentTask $specialist 'BLOCKED' '専門経路へ依頼' '独立結果を回収できませんでした' 'UNVERIFIED' 'Zeroが利用可能な証拠で判定'}
            }
            foreach($child in @($currentTask.children)){
                if($child.assigned_agent -eq 'codex'){
                    $child.status='COMPLETED'
                    $child.updated_at=[DateTime]::UtcNow.ToString('o')
                }
            }
            $judge=Invoke-AI5DoubleJudge $currentTask
            if($judge.decision-eq'REWORK'){
                Set-TaskState $currentTask $currentTaskPath 'retrying' "Zero + Codex REWORK cycle $($judge.cycle)"
                & "$bridge\bridge.ps1" enqueue -TaskId $envelope.task_id -Instruction ($envelope.instruction+"`nREWORK: "+$judge.reason) -Workspace $workspace -Retry | Out-Null
                Save-Task $currentTask $currentTaskPath
                Write-WorkerLog 'autonomous_rework_queued' @{task_id=$currentTask.taskId;cycle=$judge.cycle;reason=$judge.reason}
                $currentTask=$null;$currentTaskPath=$null;$currentEnvelopePath=$null;continue
            }
            if($judge.decision-eq'REDISPATCH'){
                Set-TaskProperty $currentTask 'assignedPrimary' $judge.redispatchTarget;Set-TaskProperty $currentTask 'assigned_agent' $judge.redispatchTarget
                Add-AI5LineMessage $currentTask 'zero' 'REDISPATCH' "$($judge.redispatchTarget)へ自動再配分します。" 'routing' @{target=$judge.redispatchTarget}
                Set-TaskState $currentTask $currentTaskPath 'retrying' "Zero REDISPATCH → $($judge.redispatchTarget)";Remove-Item -LiteralPath $file.FullName -Force;$currentTask=$null;$currentTaskPath=$null;$currentEnvelopePath=$null;continue
            }
            Set-TaskState $currentTask $currentTaskPath $(if($judge.decision-eq'COMPLETE'){'completed'}elseif($judge.decision-eq'WAITING_APPROVAL'){'waiting_approval'}else{'failed'}) "Zero + Codex: $($judge.decision)"
        } else {
            $null=Initialize-AI5LoopTask $currentTask
            Add-AI5AgentReport $currentTask 'codex' 'FAILED' '施工・検査' $summary ([string]$result.error) '安全な自動再施工またはZero再配分'
            Set-TaskProperty $currentTask 'errorType' 'task_failed'
            $untrusted=([string]$result.error)-match'(?i)(not inside a trusted directory|UNTRUSTED_WORKDIR|git root unavailable)';if($untrusted){Set-TaskProperty $currentTask 'errorType' 'UNTRUSTED_WORKDIR';$currentTask.result.failureReason='UNTRUSTED_WORKDIR';$currentTask.result.next_action='REPAIR_ENVIRONMENT_AND_RETRY';Add-AI5LineMessage $currentTask 'codex' 'REWORK' '作業場所の認識に失敗。canonical worktreeを自動修復します。本人操作は不要です。' 'environment_repair'}
            $fingerprintSource = if($untrusted){'UNTRUSTED_WORKDIR'}elseif ($result.error) { [string]$result.error } else { 'task_failed' }
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $fingerprint = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($fingerprintSource)))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
            $seen = @($currentTask.failure_fingerprints)
            Set-TaskProperty $currentTask 'failure_fingerprints' @($seen + $fingerprint)
            $repeatCount = @($seen | Where-Object { $_ -eq $fingerprint }).Count
            $canRetry = !$untrusted -and [bool]$result.retryable -and ![bool]$result.human_action_required -and [int]$currentTask.attempt -lt [int]$currentTask.max_attempts -and $repeatCount -lt 2
            if ($canRetry) {
                Set-TaskState $currentTask $currentTaskPath 'retrying' 'Codex failure classified; safe retry queued'
                & "$bridge\bridge.ps1" enqueue -TaskId $envelope.task_id -Instruction $envelope.instruction -Workspace $workspace -Retry | Out-Null
                Write-WorkerLog 'codex_retry_queued' @{ task_id = $currentTask.taskId; attempt = $currentTask.attempt; fingerprint = $fingerprint }
                $currentTask = $null
                $currentTaskPath = $null
                $currentEnvelopePath = $null
                continue
            }
            Set-TaskState $currentTask $currentTaskPath 'failed' $(if($untrusted){'Canonical worktree repair required before retry'}elseif($repeatCount-ge2){'Repeated Codex failure stopped'}else{'Codex execution failed'})
        }

        Save-Task $currentTask $currentTaskPath
        Write-WorkerLog 'codex_finished' @{
            task_id = $currentTask.taskId
            status = $currentTask.status
            session_id = $result.codex_session_id
        }
        Remove-Item -LiteralPath $file.FullName -Force
        $currentTask = $null
        $currentTaskPath = $null
        $currentEnvelopePath = $null
    }
} catch {
    $message = $_.Exception.Message
    Write-WorkerLog 'codex_worker_crash' @{ error = $message }
    if ($currentTask -and $currentTaskPath -and (Test-Path $currentTaskPath)) {
        Set-TaskProperty $currentTask 'errorType' 'bridge_unavailable'
        $currentTask.result = [ordered]@{
            status = 'failed'
            summary = 'Codex worker stopped unexpectedly'
            details = @()
            filesChanged = @()
            tests = @()
            warnings = @($message)
            failureReason = 'bridge_unavailable'
            retryable = $true
            userActionRequired = $false
        }
        Set-TaskState $currentTask $currentTaskPath 'failed' 'Codex worker stopped unexpectedly'
    }
} finally {
    if ($currentEnvelopePath -and (Test-Path $currentEnvelopePath)) {
        Remove-Item -LiteralPath $currentEnvelopePath -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $workerLock -Force -ErrorAction SilentlyContinue
}
