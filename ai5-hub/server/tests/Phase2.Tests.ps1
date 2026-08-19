$ErrorActionPreference = 'Stop'
$server = Split-Path $PSScriptRoot
$app = Split-Path $server
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'task-service\CodexService.ps1'))))
$serviceSource=Get-Content -Raw -Encoding UTF8 (Join-Path $server 'task-service\CodexService.ps1');if($serviceSource-notmatch"Join-Path \`$PSHOME 'pwsh.exe'"){throw 'UTF-8 pwsh worker launcher missing'}
Initialize-AI5CodexService $server $app
$one = Get-AI5CodexSignature 'task_phase2_signature' 'read only'
$two = Get-AI5CodexSignature 'task_phase2_signature' 'read only'
$tampered = Get-AI5CodexSignature 'task_phase2_signature' 'changed'
$contextOne = Get-AI5CodexSignature 'task_phase2_signature' 'read only' '{"projectId":"one"}'
$contextTwo = Get-AI5CodexSignature 'task_phase2_signature' 'read only' '{"projectId":"two"}'
if ($one -ne $two) { throw 'HMAC signature is not deterministic' }
if ($one -eq $tampered) { throw 'HMAC signature did not reject changed content' }
if ($contextOne -eq $contextTwo -or $contextOne -eq $one) { throw 'HMAC v2 project context is not protected' }
$routedTask = [pscustomobject]@{message='過去資料を照合';assignedSecondary=@('notebooklm','claude');execution_plan=[pscustomobject]@{mode='parallel_safe'}}
$routedInstruction = Get-AI5CodexInstruction $routedTask
if ($routedInstruction -notmatch 'NotebookLM: read-only' -or $routedInstruction -notmatch 'Claude Code CLI' -or $routedInstruction -notmatch 'Do not fabricate') { throw 'specialist orchestration contract missing' }
$parseErrors = $null
[Management.Automation.Language.Parser]::ParseFile((Join-Path $server 'server.ps1'), [ref]$null, [ref]$parseErrors) | Out-Null
if ($parseErrors) { throw ($parseErrors.Message -join '; ') }
Write-Output 'PHASE2_SECURITY_TESTS_OK'
