function Initialize-AI5LoopTask {
  param($Task)
  if($null-eq$Task.line_messages){$Task|Add-Member line_messages @() -Force}
  if($null-eq$Task.agent_reports){$Task|Add-Member agent_reports @() -Force}
  if($null-eq$Task.judgements){$Task|Add-Member judgements @() -Force}
  if($null-eq$Task.loop_state){$Task|Add-Member loop_state ([ordered]@{cycle=0;maxCycles=3;decision='PLAN';reason='created';updatedAt=[DateTime]::UtcNow.ToString('o')}) -Force}
  $Task
}
function Add-AI5LineMessage {
  param($Task,[string]$Agent,[string]$State,[string]$Text,[string]$Kind='report',$Meta=$null)
  $null=Initialize-AI5LoopTask $Task;$Task.line_messages+=,[ordered]@{id=([guid]::NewGuid().ToString('N'));taskId=$Task.taskId;agent=$Agent;state=$State;text=$Text;kind=$Kind;at=[DateTime]::UtcNow.ToString('o');meta=$Meta}
}
function Add-AI5AgentReport {
  param($Task,[string]$Agent,[string]$State,[string]$Did,[string]$Result,[string]$Problem='なし',[string]$Next='Zero判定')
  $null=Initialize-AI5LoopTask $Task;$report=[ordered]@{agent=$Agent;state=$State;did=$Did;result=$Result;problem=$Problem;next=$Next;at=[DateTime]::UtcNow.ToString('o')};$Task.agent_reports+=,$report
  Add-AI5LineMessage $Task $Agent $State "状態：$State`nやったこと：$Did`n結果：$Result`n問題：$Problem`n次の推奨：$Next" 'agent_report' $report
}
function Invoke-AI5DoubleJudge {
  param($Task)
  $null=Initialize-AI5LoopTask $Task;$result=$Task.result;$tests=@($result.tests);$failed=@($tests|Where-Object{$_-match'(?i)fail|error|ng'});$codeWork=$Task.route.workType-in@('code','pc_task');$testEvidence=(!$codeWork-or$tests.Count-gt0)
  $codexPass=$result.status-in@('SUCCESS','success','COMPLETED','completed')-and!$failed.Count-and$testEvidence-and!$result.needs_human
  $codexReason=if($failed.Count){'失敗検査あり'}elseif(!$testEvidence){'技術検査証跡不足'}elseif(!$result){'Resultなし'}else{'Result・検査・Single Writerを確認'}
  $requiredBlocked=$Task.requested_target-eq'all'-and@($Task.agent_reports|Where-Object{$_.agent-ne'codex'-and$_.state-in@('FAILED','BLOCKED')}).Count-gt0
  $zeroPass=$codexPass-and![string]::IsNullOrWhiteSpace([string]$result.summary)-and!$Task.requiresApproval-and!$requiredBlocked
  $zeroReason=if($Task.requiresApproval){'本人承認が残っています'}elseif($requiredBlocked){'ALLで必須の専門AI結果が未回収'}elseif(!$codexPass){'Codex技術判定が未達'}else{'目的・結果・残承認を確認'}
  $decision=if($Task.requiresApproval){'APPROVAL'}elseif($zeroPass){'COMPLETE'}elseif([int]$Task.loop_state.cycle-lt[int]$Task.loop_state.maxCycles){'REWORK'}else{'BLOCKED'}
  $Task.judgements+=,[ordered]@{agent='codex';verdict=$(if($codexPass){'PASS'}else{'REWORK'});reason=$codexReason;at=[DateTime]::UtcNow.ToString('o')}
  Add-AI5AgentReport $Task 'codex' $(if($codexPass){'COMPLETE'}else{'REVIEW'}) '最終技術監査' $codexReason $(if($codexPass){'なし'}else{$codexReason}) $(if($codexPass){'Zero最終判定'}else{'再施工'})
  $Task.judgements+=,[ordered]@{agent='zero';verdict=$(if($zeroPass){'PASS'}else{$decision});reason=$zeroReason;at=[DateTime]::UtcNow.ToString('o')}
  Add-AI5LineMessage $Task 'zero' $decision "Zero判定：$decision`n$zeroReason" 'judgement' @{codexPass=$codexPass;zeroPass=$zeroPass}
  $Task.loop_state.decision=$decision;$Task.loop_state.reason=$(if($decision-eq'COMPLETE'){'double_pass'}else{$codexReason});$Task.loop_state.updatedAt=[DateTime]::UtcNow.ToString('o')
  if($decision-eq'REWORK'){$Task.loop_state.cycle=[int]$Task.loop_state.cycle+1}
  [ordered]@{decision=$decision;codexPass=$codexPass;zeroPass=$zeroPass;reason=$Task.loop_state.reason;cycle=$Task.loop_state.cycle}
}
function Get-AI5LineMessages {
  param([array]$Tasks,[string]$Level='NORMAL')
  $items=@($Tasks|ForEach-Object{$task=$_;@([ordered]@{id=($task.taskId+'-user');taskId=$task.taskId;agent='user';state='PLAN';text=$task.message;kind='user';at=$task.createdAt;meta=@{target=$task.requested_target;replyTo=$task.reply_to}})+@($task.line_messages)}|Where-Object{$_})|Sort-Object at
  if($Level-eq'SIMPLE'){$items=@($items|Where-Object{$_.kind-eq'user'-or($_.kind-in@('judgement','agent_report')-and($_.state-in@('COMPLETE','FAILED','BLOCKED','WAITING_APPROVAL')))})}
  $items
}
