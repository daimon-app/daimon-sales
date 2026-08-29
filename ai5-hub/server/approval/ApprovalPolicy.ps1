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
    $level = 0; $type = 'safe_operation'; $label = 'AI5自動承認'; $reason = '安全で可逆な通常作業です。'; $recommendation = '承認推奨'
    $level2 = '支払|課金|購入|送金|返金|資金移動|銀行|有料契約|サブスクリプション|投資|税務|法的|宣誓|署名|kyc|otp|captcha|本人確認|パスワード|秘密鍵|private key|アカウント削除|不可逆|force push|reset --hard|大量削除'
    $money = '支払|課金|購入|送金|返金|資金移動|銀行|有料広告|有料契約|サブスクリプション|投資'
    $level1 = '新規公開|本番公開|sns投稿|外部送信|販売開始|新商品|新しい国|新価格|営業メール|affiliate申請.{0,12}(送信|提出)|外部サービス.{0,12}(登録|申込)|公開設定変更'
    $level0 = 'こんにちは|ありがとう|了解|おはよう|こんばんは|read.?only|読み取り|確認|調査|分析|監査|コード|実装|修正|test|テスト|lint|build|ビルド|commit|push|remote verify|result bus|evidence|decision log|task|retry|再試行|隔離|ログ|計測|utm|候補|比較|翻訳|日本語ui|landing|demo|private|非公開|rollback|ロールバック|git|github|windows|pc|資料'
    if ($text -match $level2) {
        $level = 2; $type = $(if($text -match $money){'money_or_contract'}else{'owner_only'}); $label = $(if($type-eq'money_or_contract'){'支払い・契約の確認'}else{'本人操作が必要'}); $reason = '本人以外が代理できない重要操作を含みます。'; $recommendation = '内容確認後に本人が操作'
    } elseif ($text -match $level1) {
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
    $Task|Add-Member -NotePropertyName approval -NotePropertyValue ([pscustomobject][ordered]@{type=$policy.type;level=$policy.level;summary=$policy.label;reason=$policy.reason;recommendation=$policy.recommendation;status=$(if($Task.requiresApproval){'pending'}else{'approved'});ownerOperationRequired=$policy.ownerOperationRequired;scopeHash=$policy.scopeHash;reusedApprovalId=$policy.reusedApprovalId;zero_review=(Get-AI5ZeroApprovalReview ([pscustomobject]@{approvalType=$policy.type}))}) -Force
    Register-AI5ApprovalRequest $Task $policy|Out-Null
    $Task
}

function Test-AI5AccountEvidence {
    param($Evidence,$Registry)
    $accountId=[string]$Evidence.accountId;$channelId=[string]$Evidence.channelId;$name=[string]$Evidence.accountName
    $matches=@($Registry|Where-Object{($_.accountId-and[string]$_.accountId-eq$accountId)-or($_.channelId-and[string]$_.channelId-eq$channelId)})
    if($matches.Count){return [ordered]@{status='VERIFIED_BY_AI5';ownerGate=$false;postingAllowed=$true;matchedBy=$(if($accountId){'accountId'}else{'channelId'});account=$matches[0]}}
    if($Evidence.isPersonal-or$name-match'鉄兵|個人'){return [ordered]@{status='WRONG_ACCOUNT';ownerGate=$false;postingAllowed=$false;nextAction='正しいDAIMON販売アカウントを探索';account=$null}}
    [ordered]@{status='UNRESOLVED';ownerGate=$false;postingAllowed=$false;nextAction='当該媒体Taskのみ保留し、他Taskを継続';account=$null}
}
