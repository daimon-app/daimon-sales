$ErrorActionPreference='Stop';$root=Split-Path (Split-Path $PSScriptRoot)
$app=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app.js')
foreach($required in @('AI5 HUB 本人承認待ち','approvalNotified','AI5 HUB 完了','AI5 HUB 重大失敗')){if($app-notmatch[regex]::Escape($required)){throw"notification missing: $required"}}
if($app-notmatch 'task.status==="waiting_approval"'){throw'approval notification trigger missing'}
foreach($required in @('PushManager','/api/push/public-key','/api/push/subscribe','pushSubscribed')){if($app-notmatch[regex]::Escape($required)){throw"background push missing: $required"}}
$worker=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'service-worker.js')
if($worker-notmatch "addEventListener\('push'"-or$worker-notmatch"addEventListener\('notificationclick'"){throw'service worker push handlers missing'}
'NOTIFICATION_UI_TESTS_OK'
