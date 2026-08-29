$ErrorActionPreference='Stop';$app=Split-Path (Split-Path $PSScriptRoot);$server=Join-Path ([IO.Path]::GetTempPath()) ('ai5-approval-schedule-'+[Guid]::NewGuid().ToString('N'))
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $app 'server\notifications\PushNotification.ps1'))))
try{
 Initialize-AI5PushNotifications $server $app;$tasks=@([pscustomobject]@{taskId='approval-one';status='waiting_approval'},[pscustomobject]@{taskId='approval-two';status='waiting_approval'})
 $before=Invoke-AI5ApprovalNotificationSchedule -Tasks $tasks -Now ([DateTimeOffset]::Parse('2026-08-19T09:59:00+09:00'));if($before.reason-ne'not_due'){throw 'notification sent before slot'}
 $slot=Invoke-AI5ApprovalNotificationSchedule -Tasks $tasks -Now ([DateTimeOffset]::Parse('2026-08-19T10:00:00+09:00'));if($slot.event-ne'approval-2026-08-19-1000'-or$slot.pending-ne2){throw '10:00 aggregation failed'}
 $repeat=Invoke-AI5ApprovalNotificationSchedule -Tasks $tasks -Now ([DateTimeOffset]::Parse('2026-08-19T10:10:00+09:00'));if($repeat.reason-ne'not_due'){throw 'slot duplicate was not suppressed'}
 $new=@($tasks+[pscustomobject]@{taskId='approval-three';status='waiting_approval'});$null=Invoke-AI5ApprovalNotificationSchedule -Tasks $new -Now ([DateTimeOffset]::Parse('2026-08-19T18:01:00+09:00'));$after=Invoke-AI5ApprovalNotificationSchedule -Tasks $new -Now ([DateTimeOffset]::Parse('2026-08-19T18:02:01+09:00'));if($after.event-notmatch'after'-or$after.pending-ne3){throw 'after-hours debounce failed'}
 'APPROVAL_NOTIFICATION_SCHEDULE_TESTS_OK'
}finally{if(Test-Path $server){Remove-Item -LiteralPath $server -Recurse -Force}}
