$ErrorActionPreference='Stop';$root=Split-Path (Split-Path $PSScriptRoot)
$app=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app.js')
$command=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'server\command-center\CommandCenter.ps1')
foreach($required in @('approvalNotified','refreshCommandCenter','silent_in_app')){if(($app+$command)-notmatch[regex]::Escape($required)){throw "notification/command contract missing: $required"}}
if($app-match "notify\('AI5 HUB 完了'"-or$app-match"notify\('AI5 HUB 本人承認待ち'"){throw 'browser notification bypasses approval schedule'}
foreach($required in @('PushManager','/api/push/public-key','/api/push/subscribe','pushSubscribed')){if($app-notmatch[regex]::Escape($required)){throw"background push missing: $required"}}
$worker=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'service-worker.js')
if($worker-notmatch "addEventListener\('push'"-or$worker-notmatch"addEventListener\('notificationclick'"){throw 'service worker push handlers missing'}
'NOTIFICATION_UI_TESTS_OK'
