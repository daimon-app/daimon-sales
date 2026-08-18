function Get-AI5ClaudeHealth {
  $command=Get-Command claude -ErrorAction SilentlyContinue
  [ordered]@{available=[bool]$command;connection=$(if($command){'official_cli'}else{'not_connected'});quota='unknown'}
}
function Invoke-AI5ClaudeAdapter {
  param($Task)
  $primaryResult=if($Task.result){Protect-AI5Text([string]$Task.result.summary)}else{'not supplied'}
  $prompt="You are the independent read-only Claude reviewer in AI5 HUB. Verify the objective and the primary AI result. Do not use tools, edit files, run commands, spend money, publish, or request secrets. Return PASS only when the claimed result is coherent with the stated evidence and acceptance criteria; otherwise begin with FAIL and state why. Use concise ASCII English. TASK ID: $($Task.taskId) OBJECTIVE: $($Task.objective) ACCEPTANCE: $(@($Task.acceptance_criteria)-join'; ') PRIMARY RESULT: $primaryResult EVIDENCE: $(@($Task.result.evidence)-join'; ') TESTS: $(@($Task.result.tests)-join'; ') QA: $(@($Task.result.qa)-join'; ')"
  try {
    $raw=& claude -p --tools '' --permission-mode dontAsk --no-session-persistence --output-format text $prompt 2>&1
    if($LASTEXITCODE-ne 0){throw ($raw -join "`n")}
    $summary=Protect-AI5Text (($raw -join "`n").Trim())
    if([string]::IsNullOrWhiteSpace($summary)){throw 'Claude returned an empty review'}
    $verdict=if($summary-match'(?i)^\s*FAIL\b'){'FAIL'}else{'PASS'}
    [ordered]@{task_id=$Task.taskId;ai='claude';agent='claude';result=$summary;summary=$summary;verdict=$verdict;status=$(if($verdict-eq'PASS'){'SUCCESS'}else{'FAILED'});evidence=@('Claude Code CLI result');files_changed=@();commit='';tests=@('Claude read-only review completed');qa=@('read-only review completed');blockers=$(if($verdict-eq'FAIL'){@($summary)}else{@()});resource_status='AVAILABLE';approval_required=$false;recommended_next_action=$(if($verdict-eq'PASS'){'ZERO_VALIDATE'}else{'REWORK'});findings=@($summary);changes=@();artifacts=@();risks=$(if($verdict-eq'FAIL'){@($summary)}else{@()});next_action=$(if($verdict-eq'PASS'){'ZERO_VALIDATE'}else{'REWORK'});needs_human=$false;human_reason=$null}
  }catch{$reason=Protect-AI5Text $_.Exception.Message;[ordered]@{task_id=$Task.taskId;ai='claude';agent='claude';result='Claude review failed';summary='Claude review failed';verdict='FAIL';status='FAILED';evidence=@();files_changed=@();commit='';tests=@();qa=@();blockers=@($reason);resource_status='UNKNOWN';approval_required=$false;recommended_next_action='FALLBACK';findings=@();changes=@();artifacts=@();risks=@($reason);next_action='FALLBACK';needs_human=$false;human_reason=$null}}
}
