$ErrorActionPreference = 'Stop'
$server = Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'task-service\CodexService.ps1'))))

$root = Join-Path ([IO.Path]::GetTempPath()) ('ai5-utf8-' + [Guid]::NewGuid().ToString('N'))
$app = Join-Path $root 'app'
$worker = Join-Path $root 'task-service\CodexWorker.ps1'
try {
    New-Item -ItemType Directory -Force (Split-Path $worker), (Join-Path $app 'integrations\codex\zero-codex-bridge') | Out-Null
    Set-Content -LiteralPath $worker -Encoding ASCII -Value '# test worker placeholder'
    Set-Content -LiteralPath (Join-Path $app 'integrations\codex\zero-codex-bridge\bridge.ps1') -Encoding ASCII -Value '# test bridge placeholder'
    Initialize-AI5CodexService -ServerRoot $root -AppRoot $app

    # Keep this test script ASCII so Windows PowerShell 5.1 can parse it without a BOM.
    $message = -join (@(0x30C6,0x30B9,0x30C8,0x7528,0x0054,0x0061,0x0073,0x006B,0x3092,0x5B9F,0x884C,0x3057,0x3066,0x3002,0x5909,0x66F4,0x305B,0x305A,0x3001,0x691C,0x67FB,0x7D50,0x679C,0x3060,0x3051,0x8FD4,0x3057,0x3066,0x3002) | ForEach-Object { [char]$_ })
    $task = [pscustomobject]@{
        taskId = 'AI5-UTF8-0001'
        message = $message
        route = [pscustomobject]@{ risk = 'green' }
        requiresApproval = $false
        projectContext = [pscustomobject]@{projectId='test';repository='test-repo';worktreePath='C:\test';gitRoot='C:\test';branch='test'}
    }
    $result = Submit-AI5CodexTask $task
    if (!$result.accepted) { throw 'UTF-8 envelope was not accepted' }

    $path = Join-Path $root 'data\codex-inbox\AI5-UTF8-0001.json'
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { throw 'UTF-8 envelope contains a BOM' }
    $envelope = [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
    if ($envelope.instruction -cne $message) { throw 'Japanese instruction did not round-trip' }
    $contextJson=$envelope.project_context|ConvertTo-Json -Compress -Depth 10
    if ($envelope.signature -cne (Get-AI5CodexSignature $envelope.task_id $envelope.instruction $contextJson)) { throw 'UTF-8 signature mismatch' }
    'UTF8_BRIDGE_TESTS_OK'
} finally {
    if (Test-Path $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
