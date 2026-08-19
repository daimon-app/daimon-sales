$ErrorActionPreference = 'Stop'
$server = Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'storage\Store.ps1'))))
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'evidence\EvidenceStore.ps1'))))

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ai5-evidence-' + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force $tempRoot | Out-Null
    $task = [pscustomobject]@{ task_id = 'task/evidence-test'; objective = 'safe'; token = 'must-not-leak'; nested = @{ password = 'hidden'; note = 'api_key=abc123' } }
    $result = @{ status = 'PASS'; evidence = @('ok'); authorization = 'Bearer private' }
    $saved = Export-AI5TaskEvidence -AppRoot $tempRoot -Task $task -Result $result -Audit @{ verdict = 'PASS'; secret = 'hidden' }
    if (!(Test-Path -LiteralPath $saved.path) -or !$saved.sha256) { throw 'evidence_not_exported' }
    if ($saved.committed -or $saved.pushed) { throw 'git_side_effect_reported' }
    $raw = Get-Content -Raw -Encoding UTF8 $saved.path
    if ($raw -match 'must-not-leak|Bearer private|abc123|"hidden"') { throw 'secret_not_redacted' }
    $record = $raw | ConvertFrom-Json
    if ($record.task_id -ne 'task/evidence-test' -or $record.result.status -ne 'PASS') { throw 'evidence_shape_invalid' }
    if ((Split-Path $saved.path -Parent) -ne (Join-Path $tempRoot 'evidence\tasks')) { throw 'evidence_path_invalid' }
    'EVIDENCE_STORE_TESTS_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
