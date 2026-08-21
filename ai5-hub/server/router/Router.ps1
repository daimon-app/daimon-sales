function Get-AI5Route {
  param([Parameter(Mandatory=$true)][string]$Message,[string]$RequestedTarget='auto')
  $allowedTargets=@('auto','zero','codex','claude','gemini','manus','notebooklm','all')
  $RequestedTarget=$RequestedTarget.ToLowerInvariant()
  if($RequestedTarget-notin$allowedTargets){throw 'invalid_target'}
  $text = $Message.ToLowerInvariant()
  $primary = 'codex'; $secondary = @(); $kind = 'pc_task'; $intent='task'; $usesKnowledge=$false
  $addressedAgent=$null
  if($text -match '^\s*(?:manus|マナス)[\s、,:：]'){$addressedAgent='manus'}
  elseif($text -match '^\s*(?:gemini|ジェミニ)[\s、,:：]'){$addressedAgent='gemini'}
  elseif($text -match '^\s*(?:claude|クロちゃん|クロード)[\s、,:：]'){$addressedAgent='claude'}
  elseif($text -match '^\s*(?:codex|コーデックス)[\s、,:：]'){$addressedAgent='codex'}
  if ($text -match '^(こんにちは|ありがとう|了解|おはよう|こんばんは)[。!！ ]*$') {$intent='conversation'}
  if ($text -match '^(何|なぜ|どうして|教えて|質問)') {$intent='question'}
  if ($text -match 'キャンセル|中止|停止して') {$intent='cancel'}
  if ($text -match '過去資料|過去の資料|前に決め|昔の調査|議事録|pdf群|資料のどこ|過去の決定|notebooklm') { $usesKnowledge=$true; $primary='notebooklm'; $kind='knowledge_lookup' }
  if ($text -match '最新|調査|検索|google|比較|市場|ニュース') { $primary='gemini'; $kind='research' }
  if ($text -match 'web|ブラウザ|lp|販売準備|掲載|競合') { $primary='manus'; $kind='web_operation' }
  if ($text -match '厳密|監査|設計レビュー|仕様監査') { $primary='claude'; $kind='review' }
  if ($text -match 'コード|実装|修正|バグ|git|github|ファイル|windows|pc|テスト') { $primary='codex'; $kind='code' }
  if ($text -match '原因不明|難しいバグ|原因分析') { $primary='codex'; $secondary += 'claude' }
  if ($kind -eq 'code' -and $text -match '重要|本番|大規模|厳密') { $secondary += 'claude' }
  if ($text -match '販売準備') { $secondary += @('gemini','claude','codex') }
  if ($usesKnowledge -and $primary -ne 'notebooklm') { $secondary += 'notebooklm' }
  if ($usesKnowledge -and $text -match '実装|コード|現在|正本|矛盾') { $secondary += 'claude' }
  if($addressedAgent){$primary=$addressedAgent;$kind=@{codex='code';claude='review';gemini='research';manus='web_operation'}[$primary]}
  $riskEvaluation=Get-AI5ApprovalRisk $Message
  $approvalType=if($riskEvaluation.approval_class-eq'TECHNICAL_AUTO'){$null}else{$riskEvaluation.approval_class}
  $automaticPrimary=$primary
  if($RequestedTarget-eq'all'){$primary='codex';$secondary=@('claude','gemini','manus','notebooklm');$kind='full_audit'}
  elseif($RequestedTarget-ne'auto'-and$RequestedTarget-ne'zero'){
    $primary=$RequestedTarget
    $secondary=@($secondary|Where-Object{$_-ne$primary})
    $kind=@{codex='code';claude='review';gemini='research';manus='web_operation';notebooklm='knowledge_lookup'}[$primary]
    if($primary-eq'notebooklm'){$usesKnowledge=$true}
  }
  [ordered]@{
    objective=$Message; intent=$intent; workType=$kind; primary=$primary; secondary=@($secondary|Select-Object -Unique|Where-Object{$_ -ne $primary});
    externalOperation=($kind -eq 'web_operation'); gitChange=($text -match 'git|github|コード|実装|修正');
    risk=if($approvalType){'high'}elseif($text -match '変更|修正|作成'){'medium'}else{'low'};
    requiresApproval=[bool]$approvalType; approvalType=$approvalType;approvalClass=$riskEvaluation.approval_class;riskEvaluation=$riskEvaluation;
    requestedTarget=$RequestedTarget; routingMode=$(if($RequestedTarget-in@('auto','zero')){'auto'}else{'direct_via_zero'}); automaticPrimary=$automaticPrimary;
    executionMode=if(@($secondary).Count-gt 1){'parallel_safe'}else{'sequential'};
    doneWhen=if($usesKnowledge){'出典付き資料回答・GitHub正本照合・Zeroの結論'}elseif($kind -eq 'research'){'情報取得・比較・Zeroの結論'}elseif($kind -eq 'review'){'監査結果と指摘の整理'}else{'作業結果と検査結果の確認'}
  }
}

function Get-AI5ApprovalRisk {
  param([Parameter(Mandatory=$true)][string]$Message)
  $text=$Message.ToLowerInvariant();$preparation=$text-match'準備|下書き|ドラフト|直前|公開前|dry.?run|read.?only|確認|検査|テスト'
  $money=$text-match'購入|課金|決済|支払い|有料契約|プラン変更|広告費'
  $publish=(!$preparation)-and($text-match'一般公開|本番公開|販売開始|公開する|リリース実行|sns.{0,8}(投稿|公開)|広告出稿開始|boost|public repository')
  $identity=$text-match'captcha|生体認証|本人確認書類|本人確認|2fa|sms認証|規約同意|年齢確認'
  $destructive=$text-match'大量削除|不可逆|irreversible|repository削除|リポジトリ削除|production database削除|本番データベース削除|secret破棄|reset --hard|push --force|履歴書き換え'
  $class=if($destructive){'OWNER_IRREVERSIBLE'}elseif($money){'OWNER_MONEY'}elseif($publish){'OWNER_PUBLISH'}elseif($identity){'OWNER_IDENTITY'}else{'TECHNICAL_AUTO'}
  [ordered]@{approval_class=$class;reversible=(!$destructive);external_effect=($money-or$publish-or$identity);money_effect=$money;public_effect=$publish;identity_required=$identity;destructive=$destructive;scope=$(if($class-eq'TECHNICAL_AUTO'){'workspace_or_preparation'}else{'external_owner_gate'});target=$(if($class-eq'TECHNICAL_AUTO'){'ai_executor'}else{'owner'});evidence=@('message classifier','risk flags');rollback_method=$(if($destructive){'none_confirmed'}elseif($publish){'unpublish_or_release_control'}elseif($money){'provider_cancellation_policy'}else{'git revert or restore previous state'})}
}
