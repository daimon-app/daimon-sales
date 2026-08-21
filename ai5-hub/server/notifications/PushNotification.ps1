function Initialize-AI5PushNotifications {param([string]$ServerRoot,[string]$AppRoot);$script:PushServerRoot=$ServerRoot;$script:PushScript=Join-Path $AppRoot 'server\notifications\push.js';$script:PushRoot=Join-Path $ServerRoot 'runtime\push';$script:PushSubscriptions=Join-Path $script:PushRoot 'subscriptions';$script:PushSent=Join-Path $script:PushRoot 'sent';$script:ApprovalScheduleState=Join-Path $script:PushRoot 'approval-schedule.json';New-Item -ItemType Directory -Force $script:PushSubscriptions,$script:PushSent|Out-Null;$script:PushAvailable=[bool](Get-Command node -ErrorAction SilentlyContinue)-and(Test-Path $script:PushScript)-and(Test-Path (Join-Path $AppRoot 'node_modules\web-push'));if($script:PushAvailable){try{$null=& node $script:PushScript init $script:PushServerRoot|ConvertFrom-Json}catch{$script:PushAvailable=$false}}}
function Get-AI5PushPublicKey {if(!$script:PushAvailable){return $null};try{(& node $script:PushScript public-key $script:PushServerRoot|ConvertFrom-Json).publicKey}catch{$null}}
function Save-AI5PushSubscription {param($Subscription);$endpoint=[string]$Subscription.endpoint;if($endpoint-notmatch'^https://'-or!$Subscription.keys.p256dh-or!$Subscription.keys.auth){throw'invalid_push_subscription'};$sha=[Security.Cryptography.SHA256]::Create();try{$id=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($endpoint)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()};$record=[ordered]@{endpoint=$endpoint;expirationTime=$Subscription.expirationTime;keys=[ordered]@{p256dh=[string]$Subscription.keys.p256dh;auth=[string]$Subscription.keys.auth}}|ConvertTo-Json -Depth 5;[IO.File]::WriteAllText((Join-Path $script:PushSubscriptions ($id+'.json')),$record,[Text.UTF8Encoding]::new($false));[ordered]@{subscribed=$true;background=$true}}
function Send-AI5PushNotification {
    param([string]$EventId,[ValidateSet('approval','critical','money','publish','identity','irreversible','complete')][string]$Kind,[string]$TaskId='')
    $subscription = Get-ChildItem $script:PushSubscriptions -Filter '*.json' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$script:PushAvailable -or !$subscription) { return [ordered]@{sent=$false;reason='no_subscription'} }
    $safe = $EventId -replace '[^A-Za-z0-9_.-]','_'
    $marker = Join-Path $script:PushSent ($safe+'.sent')
    if (Test-Path $marker) { return [ordered]@{sent=$false;reason='duplicate'} }
    $payloadPath = Join-Path $script:PushRoot ($safe+'.payload.json')
    $title = @{approval='AI5 HUB 本人操作が必要';critical='AI5 HUB 施工停止';money='AI5 HUB 支払い確認';publish='AI5 HUB 公開確認';identity='AI5 HUB 本人操作';irreversible='AI5 HUB 元に戻せない操作';complete='AI5 HUB 完了'}[$Kind]
    $body=@{money='金額と契約条件を確認してください。';publish='一般公開される内容を確認してください。';identity='本人認証を完了してください。';irreversible='元に戻せない操作です。対象を確認してください。';critical='本人操作がないと施工を再開できません。';complete='施工が完了しました。'}[$Kind]
    if(!$body){$body='本人の判断が必要な項目を確認してください。'}
    $payload = [ordered]@{title=$title;body=$body;level=$Kind;tag=('ai5-'+$safe);url=$(if($TaskId){'/?approval='+[uri]::EscapeDataString($TaskId)}else{'/'})} | ConvertTo-Json -Compress
    [IO.File]::WriteAllText($payloadPath,$payload,[Text.UTF8Encoding]::new($false))
    try {
        $result = & node $script:PushScript send $script:PushServerRoot $payloadPath | ConvertFrom-Json
        $count = @($result.results | Where-Object status -eq 'sent').Count
        if ($count) { [IO.File]::WriteAllText($marker,[DateTime]::UtcNow.ToString('o'),[Text.Encoding]::ASCII) }
        return [ordered]@{sent=[bool]$count;count=$count}
    } catch { return [ordered]@{sent=$false;reason='send_failed'} }
    finally { Remove-Item -LiteralPath $payloadPath -Force -ErrorAction SilentlyContinue }
}

function Invoke-AI5ApprovalNotificationSchedule {
    param([array]$Tasks,[DateTimeOffset]$Now=[DateTimeOffset]::Now)
    $pending=@($Tasks|Where-Object{$_.status-eq'waiting_approval'});if(!$pending.Count){return [ordered]@{sent=$false;reason='none_pending'}}
    $state=[ordered]@{date='';slots=@();known=@{};firstSeen=@{};lastAfterHours=$null}
    if(Test-Path $script:ApprovalScheduleState){try{$saved=Get-Content -Raw -Encoding UTF8 $script:ApprovalScheduleState|ConvertFrom-Json;$state.date=$saved.date;$state.slots=@($saved.slots);foreach($p in $saved.known.psobject.Properties){$state.known[$p.Name]=$p.Value};foreach($p in $saved.firstSeen.psobject.Properties){$state.firstSeen[$p.Name]=$p.Value};$state.lastAfterHours=$saved.lastAfterHours}catch{}}
    $date=$Now.ToString('yyyy-MM-dd');if($state.date-ne$date){$state=[ordered]@{date=$date;slots=@();known=@{};firstSeen=@{};lastAfterHours=$null}}
    foreach($task in $pending){if(!$state.known.Contains($task.taskId)){$state.known[$task.taskId]=$false;$state.firstSeen[$task.taskId]=$Now.ToString('o')}}
    $minute=$Now.Hour*60+$Now.Minute;$event=$null
    foreach($slot in @(@{name='1000';minute=600},@{name='1200';minute=720},@{name='1500';minute=900})){
      if($minute-ge$slot.minute-and$minute-lt($slot.minute+60)-and$state.slots-notcontains$slot.name){$event="approval-$date-$($slot.name)";$state.slots+=,$slot.name;foreach($task in $pending){$state.known[$task.taskId]=$true};break}
    }
    if(!$event-and$minute-ge1080){
      $ready=@($pending|Where-Object{!$state.known[$_.taskId]-and($Now-[DateTimeOffset]::Parse($state.firstSeen[$_.taskId])).TotalSeconds-ge60})
      $last=if($state.lastAfterHours){[DateTimeOffset]::Parse($state.lastAfterHours)}else{$Now.AddHours(-1)}
      if($ready.Count-and($Now-$last).TotalMinutes-ge5){$event="approval-$date-after-$($Now.ToString('HHmm'))";$state.lastAfterHours=$Now.ToString('o');foreach($task in $ready){$state.known[$task.taskId]=$true}}
    }
    [IO.File]::WriteAllText($script:ApprovalScheduleState,($state|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
    if(!$event){return [ordered]@{sent=$false;reason='not_due';pending=$pending.Count}}
    $first=@($pending|Sort-Object createdAt|Select-Object -First 1)[0];$class=[string]$first.route.approvalClass;$kind=@{OWNER_MONEY='money';OWNER_PUBLISH='publish';OWNER_IDENTITY='identity';OWNER_IRREVERSIBLE='irreversible'}[$class];if(!$kind){$kind='approval'}
    $result=Send-AI5PushNotification $event $kind $first.taskId;$result.pending=$pending.Count;$result.event=$event;$result.taskId=$first.taskId;$result
}
