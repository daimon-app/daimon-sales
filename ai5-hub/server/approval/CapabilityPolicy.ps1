$script:AI5ApprovalCapabilities = @(
    'payment', 'purchase', 'contract', 'ads', 'oauth', '2fa', 'captcha',
    'identity', 'sns_publish', 'dm_send', 'main_merge', 'production_publish',
    'google_play_publish', 'sale_start', 'irreversible',
    'secret_external_send', 'account_create'
)

function ConvertTo-AI5CanonicalOperation {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return '' }
    $raw = ([string]$Value).Trim().ToLowerInvariant()
    if (-not $raw) { return '' }
    $token = ($raw -replace '[\s\-\/]+', '_') -replace '_+', '_'

    $aliases = @{
        'pay'='payment'; '支払い'='payment'; '決済'='payment'; '課金'='payment'
        'buy'='purchase'; '購入'='purchase'
        'subscribe'='contract'; 'subscription'='contract'; '契約'='contract'; '有料契約'='contract'
        'advertise'='ads'; 'advertising'='ads'; '広告'='ads'; '広告出稿'='ads'
        'oauth_authorize'='oauth'; 'oauth認証'='oauth'
        'two_factor'='2fa'; 'two_factor_auth'='2fa'; '二段階認証'='2fa'
        '本人確認'='identity'; 'identity_verification'='identity'
        'sns_post'='sns_publish'; 'social_publish'='sns_publish'; 'sns公開投稿'='sns_publish'; 'sns投稿'='sns_publish'
        'direct_message'='dm_send'; 'send_dm'='dm_send'; 'dm送信'='dm_send'
        'merge_main'='main_merge'; 'mainへmerge'='main_merge'; 'mainマージ'='main_merge'
        'publish_production'='production_publish'; 'deploy_production'='production_publish'; '本番公開'='production_publish'
        'play_publish'='google_play_publish'; 'google_play公開'='google_play_publish'
        'start_sale'='sale_start'; '販売開始'='sale_start'
        'destructive'='irreversible'; '不可逆操作'='irreversible'; '回復不能'='irreversible'
        'send_secret'='secret_external_send'; '秘密情報外部送信'='secret_external_send'
        'create_account'='account_create'; 'アカウント作成'='account_create'; '新規アカウント作成'='account_create'
        'read'='read_only'; 'readonly'='read_only'; 'read_only'='read_only'; 'inspect'='read_only'; 'audit'='read_only'; 'review'='read_only'; '調査'='read_only'; '監査'='read_only'; '閲覧'='read_only'; '確認'='read_only'
    }
    if ($aliases.ContainsKey($token)) { return $aliases[$token] }
    return $token
}

function Find-AI5ApprovalCapability {
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $patterns = [ordered]@{
        payment='(?i)\b(payment|pay|billing|charge)\b|支払い|決済|課金'
        purchase='(?i)\b(purchase|buy)\b|購入'
        contract='(?i)\b(contract|subscribe|subscription)\b|契約(?:する|締結|変更|開始)|有料契約'
        ads='(?i)\b(advertis(?:e|ing)|ads?|campaign launch)\b|広告出稿'
        oauth='(?i)\boauth\b|OAuth認証'
        '2fa'='(?i)\b2fa\b|two.factor|二段階認証'
        captcha='(?i)\bcaptcha\b|キャプチャ認証'
        identity='(?i)identity verification|本人確認'
        sns_publish='(?i)\b(sns|social).{0,12}\b(publish|post)\b|SNS.{0,8}(公開|投稿)'
        dm_send='(?i)\b(send.{0,5}dm|direct message)\b|DM送信'
        main_merge='(?i)\bmerge.{0,8}\bmain\b|\bmain.{0,8}\bmerge\b|main.{0,5}(マージ|統合)'
        production_publish='(?i)\b(production deploy|publish production|go live)\b|本番公開|本番デプロイ'
        google_play_publish='(?i)google play.{0,12}(publish|release)|Google Play.{0,8}(公開|リリース)'
        sale_start='(?i)\b(start sales?|launch sales?)\b|販売開始'
        irreversible='(?i)\b(irreversible|destructive)\b|不可逆|回復不能'
        secret_external_send='(?i)\b(send|share|upload).{0,20}(secret|password|token|credential)\b|秘密情報.{0,8}(外部送信|送信|共有)'
        account_create='(?i)\b(create|register).{0,10}(account|profile)\b|アカウント.{0,5}(作成|登録)'
    }
    foreach ($entry in $patterns.GetEnumerator()) {
        if ($Text -match $entry.Value) { return [string]$entry.Key }
    }
    return ''
}

function Test-AI5CapabilityPolicy {
    param([Parameter(Mandatory=$true)]$Body)

    $hasTypedOperation = $null -ne $Body -and
        $null -ne $Body.PSObject.Properties['operation'] -and
        -not [string]::IsNullOrWhiteSpace([string]$Body.operation)

    if ($hasTypedOperation) {
        $operation = ConvertTo-AI5CanonicalOperation $Body.operation
        $source = 'typed_operation'
        $capability = if ($operation -in $script:AI5ApprovalCapabilities) { $operation } else { '' }
        if ($operation -notin @($script:AI5ApprovalCapabilities + @('read_only','code_change','test','build','git_commit','git_push_branch'))) {
            return [pscustomobject][ordered]@{decision='DENY';allowed=$false;approvalRequired=$false;operation=$operation;capability='';source=$source;reason='UNKNOWN_TYPED_OPERATION'}
        }
    } else {
        $parts = @('message','objective','action','description') | ForEach-Object {
            if ($null -ne $Body.PSObject.Properties[$_]) { [string]$Body.$_ }
        }
        $capability = Find-AI5ApprovalCapability ($parts -join ' ')
        $operation = if ($capability) { $capability } else { 'read_only' }
        $source = 'text_fallback'
    }

    $approvalRequired = -not [string]::IsNullOrWhiteSpace($capability)
    [pscustomobject][ordered]@{
        decision = if ($approvalRequired) { 'APPROVAL_REQUIRED' } else { 'ALLOW' }
        allowed = -not $approvalRequired
        approvalRequired = $approvalRequired
        operation = $operation
        capability = $capability
        source = $source
        reason = if ($approvalRequired) { "CAPABILITY_GATE:$capability" } else { 'SAFE_OPERATION' }
    }
}
