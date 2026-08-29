$ErrorActionPreference = 'Stop'
$server = Split-Path $PSScriptRoot
$app = Split-Path $server
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'task-service\CodexService.ps1'))))
$serviceSource=Get-Content -Raw -Encoding UTF8 (Join-Path $server 'task-service\CodexService.ps1');if($serviceSource-notmatch"Join-Path \`$PSHOME 'pwsh.exe'"){throw 'UTF-8 pwsh worker launcher missing'}
$workerSource=Get-Content -Raw -Encoding UTF8 (Join-Path $server 'task-service\CodexWorker.ps1');$serviceSource=Get-Content -Raw -Encoding UTF8 (Join-Path $server 'task-service\CodexService.ps1');$bridgeSource=Get-Content -Raw -Encoding UTF8 (Join-Path $app 'integrations\codex\zero-codex-bridge\bridge.ps1');if($workerSource-notmatch'UNTRUSTED_WORKDIR'-or$workerSource-notmatch'rev-parse --show-toplevel'-or$workerSource-notmatch'origin does not match signed Project context'){throw'Codex canonical worktree preflight missing'};if($bridgeSource-match'skip-git-repo-check'-or$bridgeSource-notmatch'WorkingDirectory \$workspace'){throw'Bridge trusted-workdir enforcement failed'};if($workerSource-notmatch"ExecutionClass-eq'READ_ONLY'"-or$serviceSource-notmatch'codex-readonly-worker.lock'-or$bridgeSource-notmatch"Lane-eq'default'"){throw 'Codex read-only parallel lane missing'}
$mobileSource=Get-Content -Raw -Encoding UTF8 (Join-Path $app 'start-mobile.ps1');if($mobileSource-notmatch'Get-Command pwsh.exe'-or$mobileSource-notmatch'AI5_STATE_ROOT'){throw 'stable launcher must use pwsh and persistent state root'}
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
