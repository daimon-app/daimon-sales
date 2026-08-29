function Initialize-AI5ResourceCommander {
  param([string]$ServerRoot)
  $script:AI5CreditRegistryRoot=Join-Path $ServerRoot 'runtime\credit-registry'
  New-Item -ItemType Directory -Force $script:AI5CreditRegistryRoot|Out-Null
}

function ConvertTo-AI5CreditState {
  param([string]$Agent,$Health)
  $quota=[string]$Health.quota;$connection=[string]$Health.connection;$percent=$null;$evidence='取得可能な正式情報がありません'
  if($quota-match'(?i)(\d{1,3})\s*%'){$percent=[Math]::Min(100,[int]$Matches[1]);$evidence="実測表示: $quota"}
  $state='UNKNOWN'
  if($connection-match'(?i)rate.?limit|exhausted|usage_limit'-or$quota-match'(?i)exhausted|limit reached|制限'){$state='EXHAUSTED';$evidence="実測制限応答: $connection $quota"}
  elseif($null-ne$percent-and$percent-le10){$state='CRITICAL'}
  elseif($null-ne$percent-and$percent-le25){$state='SAVE_MODE'}
  elseif($null-ne$percent){$state='NORMAL'}
  elseif(!$Health.available-and$connection-match'not_connected|stale|offline|error'){$state='UNAVAILABLE';$evidence="実測接続状態: $connection"}
  $label=@{NORMAL='十分';SAVE_MODE='少ない・節約モード';CRITICAL='危険';EXHAUSTED='制限中';UNAVAILABLE='利用不能';UNKNOWN='確認できません'}[$state]
  $fallback=@{claude=@('codex','gemini','zero');manus=@('gemini','codex','zero');gemini=@('codex','zero');codex=@('zero');zero=@()}[$Agent]
  [ordered]@{agent=$Agent;state=$state;label=$label;available=[bool]$Health.available;remainingPercent=$percent;quotaRaw=$(if($quota-and$quota-ne'unknown'){$quota}else{$null});usageToday=$null;consumptionRate=$null;recoveryAt=$null;evidence=$evidence;fallback=@($fallback);checkedAt=$(if($Health.checked_at){$Health.checked_at}else{[DateTime]::UtcNow.ToString('o')})}
}

function Get-AI5CreditRegistry {
  $bridge=Get-AI5CodexHealth
  $health=[ordered]@{
    zero=[ordered]@{available=$true;connection='local_policy';quota='unknown';checked_at=[DateTime]::UtcNow.ToString('o')}
    codex=[ordered]@{available=[bool]($script:MockMode-or$bridge.available);connection=$(if($script:MockMode){'mock'}else{$bridge.connection});quota='unknown';checked_at=[DateTime]::UtcNow.ToString('o')}
    claude=(Get-AI5ClaudeHealth)
    gemini=(Get-AI5SpecialistHealth 'gemini')
    manus=(Get-AI5ManusHealth)
  }
  $items=[ordered]@{};foreach($agent in $health.Keys){$items[$agent]=ConvertTo-AI5CreditState $agent $health[$agent]}
  $items
}

function Save-AI5ResourceDecision {
  param($Decision)
  $path=Join-Path $script:AI5CreditRegistryRoot ('decision-'+([guid]::NewGuid().ToString('N'))+'.json')
  [IO.File]::WriteAllText($path,($Decision|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
}

function Resolve-AI5ResourceAssignment {
  param($Task)
  $credits=Get-AI5CreditRegistry;$requested=[string]$Task.assignedPrimary;$selected=$requested;$reason='専門性と利用可能経路を確認';$fallbackUsed=$false
  $credit=$credits[$requested];$simpleClaude=([string]$Task.route.workType)-notin@('review')-or([string]$Task.message)-match'(?i)単純|定型|既知|再確認'
  $highValueManus=([string]$Task.message)-match'(?i)販売直前|buyer|購入者|実web|重要web|高利益'
  if($requested-eq'claude'-and($credit.state-in@('EXHAUSTED','UNAVAILABLE','CRITICAL')-or($credit.state-eq'SAVE_MODE'-and$simpleClaude))){$selected=if($Task.route.workType-eq'research'){'gemini'}else{'codex'};$reason="Claude $($credit.label)のため有限枠を保護";$fallbackUsed=$true}
  elseif($requested-eq'manus'-and($credit.state-in@('EXHAUSTED','UNAVAILABLE','CRITICAL')-or($credit.state-eq'SAVE_MODE'-and!$highValueManus))){$selected=if($credits.gemini.state-notin@('EXHAUSTED','UNAVAILABLE')){'gemini'}else{'codex'};$reason="Manus $($credit.label)のため調査・施工経路へ自動移管";$fallbackUsed=$true}
  elseif($requested-eq'gemini'-and$credit.state-in@('EXHAUSTED','UNAVAILABLE')){$selected='codex';$reason='Gemini利用不能のためCodexへ自動移管';$fallbackUsed=$true}
  elseif($requested-eq'codex'-and$credit.state-in@('EXHAUSTED','UNAVAILABLE')){$selected='zero';$reason='Codex経路利用不能のためZero安全停止判定へ移管';$fallbackUsed=$true}
  $decision=[ordered]@{taskId=$Task.taskId;requested=$requested;selected=$selected;reason=$reason;fallbackUsed=$fallbackUsed;creditState=$credit.state;creditLabel=$credit.label;evidence=$credit.evidence;expectedProfitEffect=$(if($Task.priority-in@('high','P0')){'高'}else{'未計測'});decidedAt=[DateTime]::UtcNow.ToString('o')}
  $Task.assignedPrimary=$selected;$Task.assigned_agent=$selected;$Task.route.primary=$selected
  $Task|Add-Member -NotePropertyName resourceDecision -NotePropertyValue ([pscustomobject]$decision) -Force
  if($fallbackUsed){$Task.assignedSecondary=@($Task.assignedSecondary+$requested|Where-Object{$_-ne$selected}|Select-Object -Unique);Add-AI5LineMessage $Task 'zero' 'REDISPATCH' "$requested の利用状態を確認し、$selected へ自動移管しました。Owner操作は不要です。" 'resource_fallback' $decision}
  Save-AI5ResourceDecision $decision
  $Task
}
