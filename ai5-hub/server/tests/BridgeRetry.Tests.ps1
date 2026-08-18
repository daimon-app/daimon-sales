$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path (Split-Path $PSScriptRoot)) 'integrations\codex\zero-codex-bridge\bridge.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('ai5-bridge-retry-' + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force $root | Out-Null
    Copy-Item -LiteralPath $source -Destination (Join-Path $root 'bridge.ps1')
    $script = Join-Path $root 'bridge.ps1'
    $first = & $script enqueue -TaskId task_retry_test -Instruction 'read only' | ConvertFrom-Json
    if (!$first.accepted -or $first.retry) { throw 'initial enqueue failed' }
    $path = Join-Path $root 'queue\task_retry_test.json'
    $task = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    $task.status = 'failed'; $task.attempt_count = 1; $task.error = 'temporary'
    $task | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding UTF8
    $retry = & $script enqueue -TaskId task_retry_test -Instruction 'read only' -Retry | ConvertFrom-Json
    $requeued = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    if (!$retry.accepted -or !$retry.retry -or $requeued.status -ne 'queued' -or $requeued.attempt_count -ne 1) { throw 'retry requeue failed' }
    $duplicate = & $script enqueue -TaskId task_retry_test -Instruction 'read only' | ConvertFrom-Json
    if (!$duplicate.duplicate -or $duplicate.accepted) { throw 'queued duplicate was not rejected' }
    'BRIDGE_RETRY_TESTS_OK'
} finally {
    if (Test-Path $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
