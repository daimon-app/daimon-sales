$ErrorActionPreference='Stop'
$app=Split-Path (Split-Path $PSScriptRoot)
$server=Join-Path ([IO.Path]::GetTempPath()) ('ai5-push-'+[Guid]::NewGuid().ToString('N'))
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $app 'server\notifications\PushNotification.ps1'))))
try{
  Initialize-AI5PushNotifications $server $app
  $key=Get-AI5PushPublicKey
  if(!$key-or$key.Length-lt80){throw'VAPID public key unavailable'}
  try{Save-AI5PushSubscription ([pscustomobject]@{endpoint='http://invalid';keys=[pscustomobject]@{p256dh='x';auth='y'}});throw'invalid subscription accepted'}catch{if($_.Exception.Message-eq'invalid subscription accepted'){throw}}
  $saved=Save-AI5PushSubscription ([pscustomobject]@{endpoint='https://push.invalid/subscription';expirationTime=$null;keys=[pscustomobject]@{p256dh='test-public';auth='test-auth'}})
  if(!$saved.subscribed-or@(Get-ChildItem (Join-Path $server 'runtime\push\subscriptions') -Filter '*.json').Count-ne1){throw'push subscription persistence failed'}
  Set-Content -LiteralPath (Join-Path $server 'runtime\push\sent\duplicate-test.sent') -Encoding ASCII -Value 'sent'
  $duplicate=Send-AI5PushNotification 'duplicate-test' 'completed'
  if($duplicate.reason-ne'duplicate'){throw'push duplicate suppression failed'}
  'PUSH_NOTIFICATION_TESTS_OK'
}finally{if(Test-Path $server){Remove-Item -LiteralPath $server -Recurse -Force}}
