$ErrorActionPreference='Stop'
$server=Split-Path $PSScriptRoot
function Protect-AI5Text([string]$Value){$Value}
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'orchestrator\TaskEngine.ps1'))))
$task=[pscustomobject]@{retry_count=1;max_attempts=3;assigned_ai='manus'}
if((Get-AI5FailureAction $task 'manus_timeout')-ne'REROUTE_CLAUDE'){throw 'Manus fallback failed'}
$task.assigned_ai='gemini'
if((Get-AI5FailureAction $task 'task_failed')-ne'REROUTE_MANUS'){throw 'Gemini fallback failed'}
if((Get-AI5FailureAction $task 'unknown_cause')-ne'REROUTE_CLAUDE'){throw 'Claude reroute failed'}
$task.retry_count=3
if((Get-AI5FailureAction $task 'timeout')-ne'ESCALATED'){throw 'max attempt failed'}
'TASK_ENGINE_TESTS_OK'
