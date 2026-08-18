function Initialize-AI5PushNotifications {param([string]$ServerRoot,[string]$AppRoot);$script:PushServerRoot=$ServerRoot;$script:PushScript=Join-Path $AppRoot 'server\notifications\push.js';$script:PushRoot=Join-Path $ServerRoot 'runtime\push';$script:PushSubscriptions=Join-Path $script:PushRoot 'subscriptions';$script:PushSent=Join-Path $script:PushRoot 'sent';New-Item -ItemType Directory -Force $script:PushSubscriptions,$script:PushSent|Out-Null;$script:PushAvailable=[bool](Get-Command node -ErrorAction SilentlyContinue)-and(Test-Path $script:PushScript)-and(Test-Path (Join-Path $AppRoot 'node_modules\web-push'));if($script:PushAvailable){try{$null=& node $script:PushScript init $script:PushServerRoot|ConvertFrom-Json}catch{$script:PushAvailable=$false}}}
function Get-AI5PushPublicKey {if(!$script:PushAvailable){return $null};try{(& node $script:PushScript public-key $script:PushServerRoot|ConvertFrom-Json).publicKey}catch{$null}}
function Save-AI5PushSubscription {param($Subscription);$endpoint=[string]$Subscription.endpoint;if($endpoint-notmatch'^https://'-or!$Subscription.keys.p256dh-or!$Subscription.keys.auth){throw'invalid_push_subscription'};$sha=[Security.Cryptography.SHA256]::Create();try{$id=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($endpoint)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()};$record=[ordered]@{endpoint=$endpoint;expirationTime=$Subscription.expirationTime;keys=[ordered]@{p256dh=[string]$Subscription.keys.p256dh;auth=[string]$Subscription.keys.auth}}|ConvertTo-Json -Depth 5;[IO.File]::WriteAllText((Join-Path $script:PushSubscriptions ($id+'.json')),$record,[Text.UTF8Encoding]::new($false));[ordered]@{subscribed=$true;background=$true}}
function Send-AI5PushNotification {
    param([string]$EventId,[ValidateSet('approval','completed','failed')][string]$Kind)
    $subscription = Get-ChildItem $script:PushSubscriptions -Filter '*.json' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$script:PushAvailable -or !$subscription) { return [ordered]@{sent=$false;reason='no_subscription'} }
    $safe = $EventId -replace '[^A-Za-z0-9_.-]','_'
    $marker = Join-Path $script:PushSent ($safe+'.sent')
    if (Test-Path $marker) { return [ordered]@{sent=$false;reason='duplicate'} }
    $payloadPath = Join-Path $script:PushRoot ($safe+'.payload.json')
    $title = @{approval='AI5 HUB 本人操作が必要';completed='AI5 HUB 完了';failed='AI5 HUB 重大失敗'}[$Kind]
    $payload = [ordered]@{title=$title;body='詳細は本人認証後にAI5 HUBで確認してください。';tag=('ai5-'+$safe);url='/'} | ConvertTo-Json -Compress
    [IO.File]::WriteAllText($payloadPath,$payload,[Text.UTF8Encoding]::new($false))
    try {
        $result = & node $script:PushScript send $script:PushServerRoot $payloadPath | ConvertFrom-Json
        $count = @($result.results | Where-Object status -eq 'sent').Count
        if ($count) { [IO.File]::WriteAllText($marker,[DateTime]::UtcNow.ToString('o'),[Text.Encoding]::ASCII) }
        return [ordered]@{sent=[bool]$count;count=$count}
    } catch { return [ordered]@{sent=$false;reason='send_failed'} }
    finally { Remove-Item -LiteralPath $payloadPath -Force -ErrorAction SilentlyContinue }
}
