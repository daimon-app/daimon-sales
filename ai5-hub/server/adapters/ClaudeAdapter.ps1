function Get-AI5ClaudeHealth {
  $command=Get-Command claude -ErrorAction SilentlyContinue
  [ordered]@{available=[bool]$command;connection=$(if($command){'official_cli'}else{'not_connected'});quota='unknown'}
}
function Invoke-AI5ClaudeAdapter {
  param($Task)
  $prompt="You are the read-only Claude reviewer in AI5 HUB. Review the objective precisely. Do not use tools, edit files, run commands, spend money, publish, or request secrets. Return a concise plain-text review using ASCII English characters only. TASK ID: $($Task.taskId) OBJECTIVE: $($Task.objective)"
  try {
    $raw=& claude -p --tools '' --permission-mode dontAsk --no-session-persistence --output-format text $prompt 2>&1
    if($LASTEXITCODE-ne 0){throw ($raw -join "`n")}
    $summary=Protect-AI5Text (($raw -join "`n").Trim())
    if([string]::IsNullOrWhiteSpace($summary)){throw 'Claude returned an empty review'}
    [ordered]@{task_id=$Task.taskId;agent='claude';status='SUCCESS';summary=$summary;findings=@($summary);changes=@();artifacts=@();tests=@('Claude read-only review completed');risks=@();next_action='COMPLETE';needs_human=$false;human_reason=$null}
  }catch{[ordered]@{task_id=$Task.taskId;agent='claude';status='FAILED';summary='Claude review failed';findings=@();changes=@();artifacts=@();tests=@();risks=@(Protect-AI5Text $_.Exception.Message);next_action='REROUTE';needs_human=$false;human_reason=$null}}
}
