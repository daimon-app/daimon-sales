function Initialize-AI5LoopTask {
  param($Task)
  if($null-eq$Task.line_messages){$Task|Add-Member line_messages @() -Force}
  if($null-eq$Task.agent_reports){$Task|Add-Member agent_reports @() -Force}
  if($null-eq$Task.judgements){$Task|Add-Member judgements @() -Force}
  if($null-eq$Task.loop_state){$Task|Add-Member loop_state ([ordered]@{cycle=0;maxCycles=3;decision='PLAN';reason='created';attemptCount=0;sameFailureCount=0;redispatchCount=0;dailyExecutionCount=0;executionDate=[DateTime]::UtcNow.ToString('yyyy-MM-dd');lastFailureFingerprint='';updatedAt=[DateTime]::UtcNow.ToString('o')}) -Force}
  foreach($item in @{attemptCount=0;sameFailureCount=0;redispatchCount=0;dailyExecutionCount=0;executionDate=[DateTime]::UtcNow.ToString('yyyy-MM-dd');lastFailureFingerprint=''}.GetEnumerator()){if($item.Key-notin$Task.loop_state.psobject.Properties.Name){$Task.loop_state|Add-Member $item.Key $item.Value -Force}}
  $Task
}
function Add-AI5LineMessage {
  param($Task,[string]$Agent,[string]$State,[string]$Text,[string]$Kind='report',$Meta=$null)
  $null=Initialize-AI5LoopTask $Task;$Task.line_messages+=,[ordered]@{id=([guid]::NewGuid().ToString('N'));taskId=$Task.taskId;agent=$Agent;state=$State;text=$Text;kind=$Kind;at=[DateTime]::UtcNow.ToString('o');meta=$Meta}
}
function Add-AI5AgentReport {
  param($Task,[string]$Agent,[string]$State,[string]$Did,[string]$Result,[string]$Problem='なし',[string]$Next='Zero判定')
  $null=Initialize-AI5LoopTask $Task;$source=if($Task.result.agent-eq$Agent){$Task.result}else{@($Task.agent_results|Where-Object{$_.agent-eq$Agent}|Select-Object -First 1)[0]};$report=[ordered]@{taskId=$Task.taskId;agent=$Agent;status=$State;summary=$Result;actions=@($Did)+@($source.actions)+@($source.changes);evidence=@($source.evidence)+@($source.artifacts);tests=@($source.tests);changedFiles=@($source.changedFiles)+@($source.filesChanged);issues=$(if($Problem-and$Problem-ne'なし'){@($Problem)+@($source.issues)+@($source.risks)}else{@($source.issues)+@($source.risks)});recommendation=$Next;needsRework=($State-in@('FAILED','BLOCKED','REWORK'));needsApproval=($State-eq'WAITING_APPROVAL');state=$State;did=$Did;result=$Result;problem=$Problem;next=$Next;at=[DateTime]::UtcNow.ToString('o')};$Task.agent_reports+=,$report
  $testSummary=if(@($report.tests).Count){"`n検査：$(@($report.tests)-join' / ')"}else{''};Add-AI5LineMessage $Task $Agent $State "状態：$State`nやったこと：$Did`n結果：$Result$testSummary`n問題：$Problem`n次の推奨：$Next" 'agent_report' $report
}
function Get-AI5LoopFingerprint([string]$Text){$sha=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}}
function Update-AI5LoopGuard {param($Task,[string]$Failure='');$null=Initialize-AI5LoopTask $Task;$today=[DateTime]::UtcNow.ToString('yyyy-MM-dd');if($Task.loop_state.executionDate-ne$today){$Task.loop_state.executionDate=$today;$Task.loop_state.dailyExecutionCount=0};$Task.loop_state.attemptCount=[int]$Task.loop_state.attemptCount+1;$Task.loop_state.dailyExecutionCount=[int]$Task.loop_state.dailyExecutionCount+1;if($Failure){$finger=Get-AI5LoopFingerprint $Failure;if($finger-eq$Task.loop_state.lastFailureFingerprint){$Task.loop_state.sameFailureCount=[int]$Task.loop_state.sameFailureCount+1}else{$Task.loop_state.lastFailureFingerprint=$finger;$Task.loop_state.sameFailureCount=1}};$Task.loop_state}
function Get-AI5RedispatchTarget {param($Task,[string]$Reason);if($Reason-match'(?i)browser|web|画面'){return 'manus'};if($Reason-match'(?i)latest|仕様|research|調査'){return 'gemini'};if($Reason-match'(?i)資料|過去|source'){return 'notebooklm'};if($Task.assignedPrimary-eq'codex'){return 'claude'};'codex'}
function Get-AI5ZeroLoopDecision {param($Task,$Result);$null=Initialize-AI5LoopTask $Task;$approvalPending=[bool]$Task.requiresApproval-and$Task.approval.status-ne'approved';if($approvalPending-or$Result.needs_human-or$Result.needsApproval){return [ordered]@{decision='WAITING_APPROVAL';target='';reason='本人承認境界'}};$failText=([string]$Result.failureReason)+' '+(@($Result.tests|Where-Object{$_-match'(?i)fail|error|ng'})-join' ');if($failText.Trim()){Update-AI5LoopGuard $Task $failText|Out-Null;if([int]$Task.loop_state.sameFailureCount-ge3-or[int]$Task.loop_state.dailyExecutionCount-ge10){return [ordered]@{decision='BLOCKED';target='';reason='Loop Guard'}};if($failText-match'(?i)unknown|complex|browser|web|latest|research|資料'){return [ordered]@{decision='REDISPATCH';target=(Get-AI5RedispatchTarget $Task $failText);reason=$failText}};return [ordered]@{decision='REWORK';target=$Task.assignedPrimary;reason=$failText}};[ordered]@{decision='COMPLETE_CANDIDATE';target='codex';reason='必要AI Result受領'}}
function Invoke-AI5DoubleJudge {
  param($Task)
  $null=Initialize-AI5LoopTask $Task;$result=$Task.result;$tests=@($result.tests);$failed=@($tests|Where-Object{$_-match'(?i)fail|error|ng'});$codeWork=$Task.route.workType-eq'code'-or[bool]$Task.route.gitChange;$testEvidence=(!$codeWork-or$tests.Count-gt0)
  $codexPass=$result.status-in@('SUCCESS','success','COMPLETED','completed')-and!$failed.Count-and$testEvidence-and!$result.needs_human
  $codexReason=if($failed.Count){'失敗検査あり'}elseif(!$testEvidence){'技術検査証跡不足'}elseif(!$result){'Resultなし'}else{'Result・検査・Single Writerを確認'}
  $requiredBlocked=$Task.requested_target-eq'all'-and@($Task.agent_reports|Where-Object{$_.agent-ne'codex'-and$_.state-in@('FAILED','BLOCKED')}).Count-gt0
  $approvalPending=[bool]$Task.requiresApproval-and$Task.approval.status-ne'approved'
  $zeroPass=$codexPass-and![string]::IsNullOrWhiteSpace([string]$result.summary)-and!$approvalPending-and!$requiredBlocked
  $zeroReason=if($approvalPending){'本人承認が残っています'}elseif($requiredBlocked){'ALLで必須の専門AI結果が未回収'}elseif(!$codexPass){'Codex技術判定が未達'}else{'目的・結果・残承認を確認'}
  $attemptLimitReached=$Task.max_attempts-and([int]$Task.attempt-ge[int]$Task.max_attempts)
  $candidate=Get-AI5ZeroLoopDecision $Task $result
  if($candidate.decision-eq'COMPLETE_CANDIDATE'){Add-AI5LineMessage $Task 'zero' 'COMPLETE_CANDIDATE' '全主要工程を受領。Codex最終技術監査へ進みます。' 'judgement' @{target='codex'}}
  $decision=if($approvalPending){'WAITING_APPROVAL'}elseif($zeroPass){'COMPLETE'}elseif($candidate.decision-eq'REDISPATCH'){'REDISPATCH'}elseif(!$attemptLimitReached-and[int]$Task.loop_state.cycle-lt[int]$Task.loop_state.maxCycles-and$candidate.decision-ne'BLOCKED'){'REWORK'}else{'BLOCKED'}
  $Task.judgements+=,[ordered]@{agent='codex';verdict=$(if($codexPass){'PASS'}else{'REWORK'});reason=$codexReason;at=[DateTime]::UtcNow.ToString('o')}
  Add-AI5AgentReport $Task 'codex' $(if($codexPass){'COMPLETE'}else{'REVIEW'}) '最終技術監査' $codexReason $(if($codexPass){'なし'}else{$codexReason}) $(if($codexPass){'Zero最終判定'}else{'再施工'})
  $Task.judgements+=,[ordered]@{agent='zero';verdict=$(if($zeroPass){'PASS'}else{$decision});reason=$zeroReason;target=$candidate.target;at=[DateTime]::UtcNow.ToString('o')}
  Add-AI5LineMessage $Task 'zero' $decision "Zero判定：$decision`n$zeroReason" 'judgement' @{codexPass=$codexPass;zeroPass=$zeroPass}
  $Task.loop_state.decision=$decision;$Task.loop_state.reason=$(if($decision-eq'COMPLETE'){'double_pass'}else{$codexReason});$Task.loop_state.updatedAt=[DateTime]::UtcNow.ToString('o')
  if($decision-eq'REWORK'){$Task.loop_state.cycle=[int]$Task.loop_state.cycle+1};if($decision-eq'REDISPATCH'){$Task.loop_state.redispatchCount=[int]$Task.loop_state.redispatchCount+1}
  [ordered]@{decision=$decision;zeroDecision=$candidate.decision;redispatchTarget=$candidate.target;codexPass=$codexPass;zeroPass=$zeroPass;reason=$Task.loop_state.reason;cycle=$Task.loop_state.cycle}
}
function Get-AI5LineMessages {
  param([array]$Tasks,[string]$Level='NORMAL')
  $raw=@($Tasks|ForEach-Object{$task=$_;@([ordered]@{id=($task.taskId+'-user');taskId=$task.taskId;agent='user';state='PLAN';text=$task.message;kind='user';at=$task.createdAt;meta=@{target=$task.requested_target;replyTo=$task.reply_to}})+@($task.line_messages)}|Where-Object{$_}|Sort-Object at);$seen=@{};$items=@($raw|Where-Object{if($seen.ContainsKey($_.id)){$false}else{$seen[$_.id]=$true;$true}})
  if($Level-eq'SIMPLE'){$items=@($items|Where-Object{$_.kind-eq'user'-or($_.kind-in@('judgement','agent_report')-and($_.state-in@('COMPLETE','FAILED','BLOCKED','WAITING_APPROVAL')))})}
  $items
}
