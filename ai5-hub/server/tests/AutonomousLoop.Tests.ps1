$ErrorActionPreference='Stop';$server=Split-Path $PSScriptRoot;. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'orchestrator\AutonomousLoop.ps1'))))
function New-LoopTask($tests){[pscustomobject]@{taskId='loop-test';route=[pscustomobject]@{workType='code'};requiresApproval=$false;result=[pscustomobject]@{status='success';summary='施工完了';tests=@($tests);needs_human=$false;risks=@()}}}
$ok=New-LoopTask @('unit PASS');$decision=Invoke-AI5DoubleJudge $ok;if($decision.decision-ne'COMPLETE'-or$ok.agent_reports.Count-lt1-or$ok.line_messages.Count-lt2){throw 'double PASS completion failed'}
$rework=New-LoopTask @();$first=Invoke-AI5DoubleJudge $rework;if($first.decision-ne'REWORK'-or$rework.loop_state.cycle-ne1){throw 'automatic REWORK failed'}
$rework.loop_state.cycle=3;$blocked=Invoke-AI5DoubleJudge $rework;if($blocked.decision-ne'BLOCKED'){throw 'loop guard failed'}
$approval=New-LoopTask @('PASS');$approval.requiresApproval=$true;$wait=Invoke-AI5DoubleJudge $approval;if($wait.decision-ne'APPROVAL'){throw 'approval stop failed'}
if(@(Get-AI5LineMessages @($ok) 'NORMAL').Count-lt2){throw 'durable line reports missing'}
'AUTONOMOUS_LOOP_TESTS_OK'
