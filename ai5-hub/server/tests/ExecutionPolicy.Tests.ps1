$ErrorActionPreference='Stop';$server=Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'orchestrator\TaskEngine.ps1'))))
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'orchestrator\ExecutionPolicy.ps1'))))
$route=[pscustomobject]@{primary='codex';secondary=@('claude','gemini','notebooklm');executionMode='parallel_safe';requiresApproval=$false;approvalType=$null}
$plan=Get-AI5ExecutionPlan $route
if($plan.single_writer-ne'codex'){throw'single writer missing'}
if(($plan.stages|Where-Object purpose -eq 'specialist_read_only').mode-ne'parallel'){throw'parallel plan missing'}
if((Get-AI5FieldModeDecision $route $true).action-ne'AUTO_CONTINUE'){throw'field auto continue failed'}
$danger=[pscustomobject]@{requiresApproval=$true;approvalType='payment'}
if(!(Get-AI5FieldModeDecision $danger $true).stop){throw'danger did not stop'}
$task=[pscustomobject]@{attempt=1;max_attempts=3;failure_fingerprints=@('same','same')}
if((Get-AI5RecoveryDecision $task 'timeout' 'same').action-ne'FAILED'){throw'repeated failure loop allowed'}
$task.failure_fingerprints=@()
if((Get-AI5RecoveryDecision $task 'unknown_cause' 'new').action-ne'REROUTE_CLAUDE'){throw'claude recovery failed'}
'EXECUTION_POLICY_TESTS_OK'
