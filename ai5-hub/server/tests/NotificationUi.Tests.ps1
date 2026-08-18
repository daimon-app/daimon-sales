$ErrorActionPreference='Stop';$root=Split-Path (Split-Path $PSScriptRoot)
$app=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app.js')
foreach($required in @('AI5 HUB 本人承認待ち','approvalNotified','AI5 HUB 完了','AI5 HUB 重大失敗')){if($app-notmatch[regex]::Escape($required)){throw"notification missing: $required"}}
if($app-notmatch 'task.status==="waiting_approval"'){throw'approval notification trigger missing'}
'NOTIFICATION_UI_TESTS_OK'
