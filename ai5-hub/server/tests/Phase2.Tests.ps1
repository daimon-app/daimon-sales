$ErrorActionPreference = 'Stop'
$server = Split-Path $PSScriptRoot
$app = Split-Path $server
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'task-service\CodexService.ps1'))))
Initialize-AI5CodexService $server $app
$one = Get-AI5CodexSignature 'task_phase2_signature' 'read only'
$two = Get-AI5CodexSignature 'task_phase2_signature' 'read only'
$tampered = Get-AI5CodexSignature 'task_phase2_signature' 'changed'
$contextOne = Get-AI5CodexSignature 'task_phase2_signature' 'read only' '{"projectId":"one"}'
$contextTwo = Get-AI5CodexSignature 'task_phase2_signature' 'read only' '{"projectId":"two"}'
if ($one -ne $two) { throw 'HMAC signature is not deterministic' }
if ($one -eq $tampered) { throw 'HMAC signature did not reject changed content' }
if ($contextOne -eq $contextTwo -or $contextOne -eq $one) { throw 'HMAC v2 project context is not protected' }
foreach ($file in @('server.ps1', 'project-control\ProjectControl.ps1', 'project-control\ProjectRoom.ps1')) {
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile((Join-Path $server $file), [ref]$null, [ref]$parseErrors) | Out-Null
    if ($parseErrors) { throw "$file`: $($parseErrors.Message -join '; ')" }
}
Write-Output 'PHASE2_SECURITY_TESTS_OK'
