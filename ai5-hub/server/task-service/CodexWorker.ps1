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
    $task | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $path -Force
}

function Set-TaskProperty($task, $name, $value) {
    $task | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force
}

function Set-TaskState($task, $path, $status, $label) {
    $task.status = $status
    $canonical = @{ queued='RECEIVED'; planning='PLANNING'; running='RUNNING'; reviewing='VALIDATING'; completed='COMPLETED'; failed='FAILED'; cancelled='CANCELLED' }[$status]
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
        $envelope = Get-Content -Raw $file.FullName | ConvertFrom-Json
        $currentTaskPath = Join-Path $taskRoot ($envelope.task_id + '.json')
        if (!(Test-Path $currentTaskPath)) {
            Remove-Item -LiteralPath $file.FullName -Force
            continue
        }

        $currentTask = Get-Content -Raw $currentTaskPath | ConvertFrom-Json
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

        & "$bridge\bridge.ps1" enqueue -TaskId $envelope.task_id -Instruction $envelope.instruction | Out-Null
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
            ai = 'codex'
            agent = 'codex'
            result = $summary
            verdict = $(if($result.status-eq'success'){'PASS'}else{'FAIL'})
            status = $result.status
            summary = $summary
            evidence = @($result.details)
            files_changed = @($result.files_changed)
            commit = [string]$result.commit_id
            qa = @($result.tests)
            blockers = @($result.warnings)
            resource_status = 'AVAILABLE'
            approval_required = [bool]$result.human_action_required
            recommended_next_action = $(if($result.status-eq'success'){'INDEPENDENT_AUDIT'}elseif($result.retryable){'RETRY'}else{'ESCALATE_ZERO'})
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
            Set-TaskProperty $currentTask 'validation' ([ordered]@{passed=$false;checks=[ordered]@{result_schema=$true;tests=(@($result.tests).Count-gt 0);bridge_success=$true;independent_audit=$false};checked_at=[DateTime]::UtcNow.ToString('o')})
            foreach($child in @($currentTask.children)){
                if($child.assigned_agent -eq 'codex'){
                    $child.status='COMPLETED'
                    $child.updated_at=[DateTime]::UtcNow.ToString('o')
                }
            }
            Set-TaskState $currentTask $currentTaskPath 'reviewing' 'Independent Claude audit required'
        } else {
            Set-TaskProperty $currentTask 'errorType' 'task_failed'
            Set-TaskState $currentTask $currentTaskPath 'failed' 'Codex execution failed'
        }

        if($currentTask.repository_path){$postStatus=@(& git -C $currentTask.repository_path status --porcelain=v2 --untracked-files=all 2>$null);Set-TaskProperty $currentTask 'post_write_snapshot' ([ordered]@{branch=(& git -C $currentTask.repository_path branch --show-current 2>$null);head=(& git -C $currentTask.repository_path rev-parse HEAD 2>$null);dirty=($postStatus.Count-gt0);status=$postStatus;captured_at=[DateTime]::UtcNow.ToString('o')})}
        if($currentTask.repository_lock-and$currentTask.repository_lock.path-and$currentTask.repository_lock.record.task_id-eq$currentTask.taskId){Remove-Item -LiteralPath $currentTask.repository_lock.path -Force -ErrorAction SilentlyContinue;Set-TaskProperty $currentTask 'repository_lock' $null}

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
