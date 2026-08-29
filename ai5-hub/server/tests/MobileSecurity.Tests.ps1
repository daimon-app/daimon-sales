$ErrorActionPreference = 'Stop'
$server = Split-Path $PSScriptRoot
$code = Get-Content -Raw -Encoding UTF8 (Join-Path $server 'security\MobileSecurity.ps1')
. ([ScriptBlock]::Create($code))
Initialize-AI5MobileSecurity $server

$identity = [ordered]@{ login = 'mobile-test@example.invalid'; name = 'Mobile Test' }
$session = New-AI5Session $identity
if ($session.cookie -notmatch 'HttpOnly' -or $session.cookie -notmatch 'Secure' -or $session.cookie -notmatch 'SameSite=Strict') { throw 'Secure cookie flags missing' }

$token = New-AI5ApprovalToken 'task_mobile_security_test'
if (!(Use-AI5ApprovalToken 'task_mobile_security_test' $token)) { throw 'Valid approval token rejected' }
if (Use-AI5ApprovalToken 'task_mobile_security_test' $token) { throw 'Approval token reuse accepted' }
if (Use-AI5ApprovalToken 'task_mobile_security_test' 'tampered') { throw 'Tampered approval token accepted' }

Write-Output 'PHASE25_MOBILE_SECURITY_TESTS_OK'
