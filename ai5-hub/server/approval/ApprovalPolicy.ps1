function Initialize-AI5ApprovalPolicy {
    param([string]$ServerRoot)
    $script:AI5ApprovalRegistryRoot = Join-Path $ServerRoot 'runtime\approval-registry'
    New-Item -ItemType Directory -Force $script:AI5ApprovalRegistryRoot | Out-Null
}

function Get-AI5ApprovalScopeHash {
    param($Task)
    $scope = [ordered]@{
        project = [string]$Task.project_id
        operation = [string]$Task.route.approvalType
        product = [string]$Task.product
        country = [string]$Task.country
        price = [string]$Task.price
        channel = [string]$Task.channel
        objective = [string]$Task.objective
    }
    Get-AI5Hash (($scope | ConvertTo-Json -Compress))
}

function Get-AI5ApprovalClassification {
    param($Task)
    $text = (([string]$Task.message) + ' ' + ([string]$Task.objective)).ToLowerInvariant()
    $routeApprovalType = [string]$Task.route.approvalType
    $level = 0; $type = 'safe_operation'; $label = 'AI5自動承認'; $reason = '安全で可逆な通常作業です。'; $recommendation = '承認推奨'
    $level2 = '支払|課金|購入|送金|返金|資金移動|銀行|有料契約|サブスクリプション|投資|税務|法的|宣誓|署名|kyc|otp|captcha|本人確認|パスワード|秘密鍵|private key|アカウント削除|不可逆|force push|reset --hard|大量削除'
    $money = '支払|課金|購入|送金|返金|資金移動|銀行|有料広告|有料契約|サブスクリプション|投資'
    $level1 = '新規公開|本番公開|sns投稿|外部送信|販売開始|新商品|新しい国|新価格|営業メール|affiliate申請.{0,12}(送信|提出)|外部サービス.{0,12}(登録|申込)|公開設定変更'
    $level0 = 'こんにちは|ありがとう|了解|おはよう|こんばんは|read.?only|読み取り|確認|調査|分析|監査|コード|実装|修正|test|テスト|lint|build|ビルド|commit|push|remote verify|result bus|evidence|decision log|task|retry|再試行|隔離|ログ|計測|utm|候補|比較|翻訳|日本語ui|landing|demo|private|非公開|rollback|ロールバック|git|github|windows|pc|資料'
    $safeMainIntegration = $text-match'main' -and $text-match'(全回帰|回帰).{0,8}pass' -and $text-match'競合.{0,4}0' -and $text-match'非.?force' -and $text-match'rollback.{0,8}(ready|可能|あり)' -and $text-match'(外部公開なし|外部公開.{0,4}0)' -and $text-match'(金銭操作なし|金銭.{0,4}0|課金なし)' -and $text-match'(秘密情報なし|秘密情報.{0,4}0)' -and $text-match'(不可逆変更なし|重大な不可逆.{0,6}なし)'
    $safeMockTest = $text-match'(模擬|mock|test|テスト|e2e)' -and $text-match'(外部操作|外部公開|外部送信).{0,6}(0|なし|禁止)' -and $text-match'(金銭|支出|課金).{0,6}(0|なし|禁止)'
    if ($safeMockTest) {
        $level = 0; $type = 'safe_mock_test'; $label = 'AI5自動テスト'; $reason = '外部操作0・金銭0を明示した安全な模擬試験です。'; $recommendation = 'Owner Gateなしで実行'
    } elseif ($safeMainIntegration) {
        $level = 0; $type = 'verified_main_integration'; $label = '検証済み通常統合'; $reason = '全回帰・競合・非force・Rollback・外部影響の安全条件を満たす通常main統合です。'; $recommendation = 'AI5自動承認で継続'
    } elseif ($text -match $level2) {
        $level = 2; $type = $(if($text -match $money){'money_or_contract'}else{'owner_only'}); $label = $(if($type-eq'money_or_contract'){'支払い・契約の確認'}else{'本人操作が必要'}); $reason = '本人以外が代理できない重要操作を含みます。'; $recommendation = '内容確認後に本人が操作'
    } elseif ($routeApprovalType -in @('external_publish','external_send','publication') -or $text -match $level1) {
        $level = 1; $type = 'hub_approval'; $label = '鉄兵の確認が必要'; $reason = '重要な外部公開または外部送信です。'; $recommendation = '内容と公開範囲を確認'
    } elseif ($text -notmatch $level0) {
        $level = 1; $type = 'unclassified'; $label = '鉄兵の確認が必要'; $reason = '操作分類を安全に確定できません。'; $recommendation = '操作範囲を確認'
    }
    [ordered]@{
        level=$level; type=$type; label=$label; reason=$reason; recommendation=$recommendation
        ownerRequired=($level-gt0); ownerOperationRequired=($level-eq2); sound=($level-gt0)
        money=($text-match$money); amount=$(if($Task.amount){$Task.amount}else{$null}); reversible=($level-lt2)
        scopeHash=(Get-AI5ApprovalScopeHash $Task); classifiedAt=[DateTime]::UtcNow.ToString('o')
    }
}

function Get-AI5ApprovalContext {
    param($Task,$Policy)
    $amount=if($null-ne$Task.amount-and[string]$Task.amount){[string]$Task.amount}elseif(([string]$Task.message)-match'([0-9,]+)\s*円'){"$($Matches[1])円"}elseif(!$Policy.money){'0円（金銭操作なし）'}else{''}
    $context=[ordered]@{
        operationContent=[string]$Task.objective
        targetItem=$(if($Task.product){[string]$Task.product}elseif($Task.taskLabel){[string]$Task.taskLabel}elseif($Task.taskId){"Task $($Task.taskId)"}else{''})
        accountService=$(if($Task.accountService){[string]$Task.accountService}elseif($Task.service){[string]$Task.service}elseif($Task.account){[string]$Task.account}elseif($Task.channel){[string]$Task.channel}else{''})
        amount=$amount
        externalImpact=$(if($Task.externalImpact){[string]$Task.externalImpact}elseif($Policy.level-eq0){'外部への影響なし'}else{''})
        reversibility=$(if($null-ne$Task.reversible){if([bool]$Task.reversible){'可逆'}else{'不可逆'}}elseif($Policy.level-eq0){'可逆'}else{''})
        specificReason=$(if($Task.approvalReason){[string]$Task.approvalReason}elseif($Policy.level-eq1){'指定した外部公開・送信を開始するため、対象と影響範囲の確認が必要です。'}elseif($Policy.level-eq2){'本人以外が代理できない金銭・認証・法的操作を含むためです。'}else{[string]$Policy.reason})
        zeroRecommendation=[string]$Policy.recommendation
        afterApproval=$(if($Task.afterApproval){[string]$Task.afterApproval}elseif($Policy.level-eq0){'AI5が自動テストを実行します。'}else{''})
    }
    $labels=[ordered]@{operationContent='操作内容';targetItem='対象商品/Task';accountService='対象アカウント/サービス';amount='金額';externalImpact='外部への影響';reversibility='可逆性';specificReason='本人承認が必要な具体的理由';zeroRecommendation='Zero推奨';afterApproval='承認後に実際に起こること'}
    $missing=@($labels.Keys|Where-Object{[string]::IsNullOrWhiteSpace([string]$context[$_])})
    [ordered]@{complete=($missing.Count-eq0);status=$(if($missing.Count){'APPROVAL_CONTEXT_INCOMPLETE'}else{'COMPLETE'});missing=$missing;labels=$labels;values=$context}
}

function Get-AI5ApprovalRegistryRecords {
    if (!(Test-Path $script:AI5ApprovalRegistryRoot)) { return @() }
    @(Get-ChildItem $script:AI5ApprovalRegistryRoot -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object { try { Get-Content -Raw -Encoding UTF8 $_.FullName | ConvertFrom-Json } catch {} })
}

function Find-AI5ReusableApproval {
    param([string]$ScopeHash)
    Get-AI5ApprovalRegistryRecords | Where-Object { $_.scopeHash-eq$ScopeHash -and $_.status-eq'approved' -and (!$_.expiresAt -or (ConvertTo-AI5UtcDateTime $_.expiresAt)-gt[DateTime]::UtcNow) } | Sort-Object approvedAt | Select-Object -Last 1
}

function Save-AI5ApprovalRegistryRecord {
    param($Record)
    $path = Join-Path $script:AI5ApprovalRegistryRoot (([string]$Record.approvalId -replace '[^A-Za-z0-9_.-]','_')+'.json')
    $temp = "$path.tmp"
    [IO.File]::WriteAllText($temp,($Record|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination $path -Force
    $Record
}

function Register-AI5ApprovalRequest {
    param($Task,$Policy)
    $id = 'approval-' + $Task.taskId
    $record = [ordered]@{approvalId=$id;taskId=$Task.taskId;projectId=$Task.project_id;scopeHash=$Policy.scopeHash;level=$Policy.level;type=$Policy.type;label=$Policy.label;reason=$Policy.reason;recommendation=$Policy.recommendation;money=$Policy.money;amount=$Policy.amount;status=$(if($Policy.level-eq0){'auto_approved'}else{'pending'});createdAt=[DateTime]::UtcNow.ToString('o');approvedAt=$(if($Policy.level-eq0){[DateTime]::UtcNow.ToString('o')}else{$null});expiresAt=$null;receiptId=$(if($Policy.level-eq0){'receipt-'+$Task.taskId}else{$null})}
    Save-AI5ApprovalRegistryRecord $record
}

function Approve-AI5ApprovalRequest {
    param([string]$TaskId,[string]$Actor='teppei')
    $record=Get-AI5ApprovalRegistryRecords|Where-Object { $_.taskId -eq $TaskId }|Sort-Object createdAt|Select-Object -Last 1
    if(!$record){throw 'approval_request_not_found'}
    if([int]$record.level-eq2){throw 'owner_operation_required'}
    if($record.status-eq'approved'){return$record}
    $record.status='approved';$record.approvedAt=[DateTime]::UtcNow.ToString('o');$record|Add-Member approvedBy $Actor -Force;$record.receiptId='receipt-'+$TaskId
    Save-AI5ApprovalRegistryRecord $record
}

function Resolve-AI5TaskApprovalPolicy {
    param($Task)
    $policy=Get-AI5ApprovalClassification $Task
    $existing=if($policy.level-eq1){Find-AI5ReusableApproval $policy.scopeHash}else{$null}
    if($existing){$policy.level=0;$policy.type='existing_scope';$policy.label='既存承認を使用';$policy.reason='完全一致する有効な承認Scopeを再利用しました。';$policy.ownerRequired=$false;$policy.sound=$false;$policy.reusedApprovalId=$existing.approvalId}
    $Task|Add-Member -NotePropertyName approvalPolicy -NotePropertyValue ([pscustomobject]$policy) -Force
    $Task.requiresApproval=[bool]$policy.ownerRequired
    $Task.approval_level=@{0='GREEN';1='YELLOW';2='RED'}[[int]$policy.level]
    $Task.status=if($Task.requiresApproval){'waiting_approval'}else{'queued'}
    $Task.canonical_status=if($Task.requiresApproval){'WAITING_APPROVAL'}else{'RECEIVED'}
    $context=Get-AI5ApprovalContext $Task $policy
    $Task|Add-Member -NotePropertyName approval -NotePropertyValue ([pscustomobject][ordered]@{type=$policy.type;level=$policy.level;summary=$policy.label;reason=$policy.reason;recommendation=$policy.recommendation;status=$(if($Task.requiresApproval){'pending'}else{'approved'});ownerOperationRequired=$policy.ownerOperationRequired;scopeHash=$policy.scopeHash;reusedApprovalId=$policy.reusedApprovalId;contextStatus=$context.status;contextComplete=$context.complete;missingContext=@($context.missing);context=$context.values;contextLabels=$context.labels;zero_review=(Get-AI5ZeroApprovalReview ([pscustomobject]@{approvalType=$policy.type}))}) -Force
    $Task|Add-Member -NotePropertyName approvalTask -NotePropertyValue ([pscustomobject](New-AI5HubApprovalPayload $Task $policy $context)) -Force
    Register-AI5ApprovalRequest $Task $policy|Out-Null
    $Task
}

function Reject-AI5ApprovalRequest {
    param([string]$TaskId,[string]$Actor='teppei')
    $record=Get-AI5ApprovalRegistryRecords|Where-Object{$_.taskId-eq$TaskId}|Sort-Object createdAt|Select-Object -Last 1
    if(!$record){throw'approval_request_not_found'}
    if($record.status-eq'rejected'){return$record}
    $record.status='rejected';$record|Add-Member rejectedAt ([DateTimeOffset]::Now.ToString('o')) -Force;$record|Add-Member rejectedBy $Actor -Force;$record.receiptId='receipt-reject-'+$TaskId
    Save-AI5ApprovalRegistryRecord $record
}

function Test-AI5AccountEvidence {
    param($Evidence,$Registry)
    $accountId=[string]$Evidence.accountId;$channelId=[string]$Evidence.channelId;$name=[string]$Evidence.accountName
    $matches=@($Registry|Where-Object{($_.accountId-and[string]$_.accountId-eq$accountId)-or($_.channelId-and[string]$_.channelId-eq$channelId)})
    if($matches.Count){return [ordered]@{status='VERIFIED_BY_AI5';ownerGate=$false;postingAllowed=$true;matchedBy=$(if($accountId){'accountId'}else{'channelId'});account=$matches[0]}}
    if($Evidence.isPersonal-or$name-match'鉄兵|個人'){return [ordered]@{status='WRONG_ACCOUNT';ownerGate=$false;postingAllowed=$false;nextAction='正しいDAIMON販売アカウントを探索';account=$null}}
    [ordered]@{status='UNRESOLVED';ownerGate=$false;postingAllowed=$false;nextAction='当該媒体Taskのみ保留し、他Taskを継続';account=$null}
}
