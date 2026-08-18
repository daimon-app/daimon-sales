function New-AI5Result {
  param([string]$TaskId,[string]$Agent,[string]$Status='SUCCESS',[string]$Summary='')
  [ordered]@{task_id=$TaskId;agent=$Agent;status=$Status;summary=$Summary;findings=@();changes=@();artifacts=@();tests=@();risks=@();next_action='VALIDATE';needs_human=$false;human_reason=$null}
}
function New-AI5Children {
  param($Task,$Route)
  $steps=@([ordered]@{title='現状調査';agent='codex';phase='inspection'},[ordered]@{title='施工';agent=$Route.primary;phase='execution'},[ordered]@{title='検査';agent='codex';phase='validation'})
  if($Route.secondary -contains 'claude' -or $Route.primary -eq 'claude'){$steps+=,[ordered]@{title='高精度レビュー';agent='claude';phase='review'}}
  if($Route.primary -eq 'gemini'){$steps+=,[ordered]@{title='調査結果統合';agent='codex';phase='integration'}}
  if($Route.primary -eq 'manus'){$steps+=,[ordered]@{title='Web結果確認';agent='codex';phase='validation'}}
  if($Route.primary -eq 'notebooklm' -or $Route.secondary -contains 'notebooklm'){$steps+=,[ordered]@{title='出典確認';agent='notebooklm';phase='knowledge_validation'};$steps+=,[ordered]@{title='GitHub正本照合';agent='codex';phase='source_of_truth_validation'}}
  $i=0;@($steps|ForEach-Object{$i++;[ordered]@{task_id=('{0}-{1:D2}' -f $Task.task_id,$i);parent_task_id=$Task.task_id;title=$_.title;assigned_agent=$_.agent;phase=$_.phase;status='RECEIVED';created_at=$Task.created_at;updated_at=$Task.created_at;result=$null}})
}
function ConvertTo-AI5LegacyStatus([string]$Status){@{RECEIVED='queued';PLANNING='planning';ROUTING='planning';RUNNING='running';VALIDATING='reviewing';RETRYING='running';BLOCKED='failed';WAITING_APPROVAL='waiting_approval';COMPLETED='completed';FAILED='failed';CANCELLED='cancelled'}[$Status]}
function Set-AI5TaskStatus {param($Task,[string]$Status,[string]$Label);$Task.canonical_status=$Status;$Task.status=ConvertTo-AI5LegacyStatus $Status;$Task.timeline+=,[ordered]@{status=$Status;label=$Label;at=[DateTime]::UtcNow.ToString('o')};Save-AI5Task $Task}
function Test-AI5Completion {
  param($Task)
  $tests=@($Task.result.tests);$hasFailure=@($tests|Where-Object{$_ -match '(?i)fail|error|ng'})
  [ordered]@{passed=($Task.result.status -in @('SUCCESS','success') -and $hasFailure.Count -eq 0);checks=[ordered]@{result_schema=($null-ne$Task.result);tests=($tests.Count-gt 0);no_reported_failure=($hasFailure.Count-eq 0)};checked_at=[DateTime]::UtcNow.ToString('o')}
}
function Get-AI5FailureAction {param($Task,[string]$ErrorType);if($Task.attempt-ge$Task.max_attempts){return 'FAILED'};if($ErrorType-in@('authentication_failed','approval_required')){return 'WAIT_APPROVAL'};if($ErrorType-in@('unknown_cause','complex_bug')){return 'REROUTE_CLAUDE'};if($ErrorType-in@('latest_spec','research_required')){return 'REROUTE_GEMINI'};if($ErrorType-in@('web_verification','browser_required')){return 'REROUTE_MANUS'};return 'RETRY_CODEX'}
