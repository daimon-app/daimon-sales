$ErrorActionPreference='Stop'
$server=Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'orchestrator\TaskEngine.ps1'))))
$task=[pscustomobject]@{attempt=1;max_attempts=3}
if((Get-AI5FailureAction $task 'timeout')-ne'RETRY_CODEX'){throw'retry failed'}
if((Get-AI5FailureAction $task 'UNTRUSTED_WORKDIR')-ne'REPAIR_ENVIRONMENT_AND_RETRY'){throw'worktree repair classification failed'}
if((Get-AI5FailureAction $task 'unknown_cause')-ne'REROUTE_CLAUDE'){throw'claude reroute failed'}
if((ConvertTo-AI5LegacyStatus 'QUEUED')-ne'queued'){throw 'canonical QUEUED did not map to legacy queue status'}
$task.attempt=3
if((Get-AI5FailureAction $task 'timeout')-ne'FAILED'){throw'max attempt failed'}
'TASK_ENGINE_TESTS_OK'
