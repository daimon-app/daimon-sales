$ErrorActionPreference='Stop'
$server=Split-Path $PSScriptRoot
function Protect-AI5Text([string]$Value){$Value}
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'orchestrator\TaskEngine.ps1'))))
$task=[pscustomobject]@{task_id='task-test';taskId='task-test'}
$body=[pscustomobject]@{task_id='task-test';ai='manus';result='done';verdict='PASS';evidence=@('artifact.md');files_changed=@();commit='';tests=@('link PASS');qa=@('mobile PASS');blockers=@();resource_status='AVAILABLE';approval_required=$false;recommended_next_action='AUDIT'}
$result=ConvertTo-AI5ReturnResult $body $task
if($result.verdict-ne'PASS'-or$result.ai-ne'manus'-or$result.evidence.Count-ne1){throw 'Zero Return conversion failed'}
$bad=$body.PSObject.Copy();$bad.task_id='wrong';$rejected=$false;try{ConvertTo-AI5ReturnResult $bad $task|Out-Null}catch{$rejected=$true};if(!$rejected){throw 'task mismatch accepted'}
'ZERO_RETURN_TESTS_OK'
