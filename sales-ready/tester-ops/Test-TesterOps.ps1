$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'TesterOps.psm1') -Force
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('daimon-tester-ops-' + [guid]::NewGuid().ToString('N'))
$store = Join-Path $testRoot 'ledger.dpapi'
$export = Join-Path $testRoot 'template.csv'
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
try {
    $record = New-TesterRecord -Email 'tester@example.invalid' -Consent $true -DeviceModel 'Test Device' -AndroidVersion '15' -AppVersion '1.0.0-test' -StorePath $store
    if ($record.PseudonymousId -notmatch '^T-') { throw 'ID test failed' }
    $raw = Get-Content -Raw $store
    if ($raw -match 'tester@example.invalid|Test Device') { throw 'PII encryption test failed' }
    $loaded = @(Read-TesterLedger $store)
    if ($loaded.Count -ne 1 -or $loaded[0].Email -ne 'tester@example.invalid') { throw 'DPAPI round-trip failed' }
    if ((Get-TesterDailySummary $store).Total -ne 1) { throw 'Summary test failed' }
    Export-TesterTemplate $export | Out-Null
    if ((Get-Content -Raw $export) -match 'Email|Consent') { throw 'PII-free export test failed' }
    try { New-TesterRecord -Email 'bad' -Consent $true -DeviceModel x -AndroidVersion x -StorePath $store; throw 'Invalid email accepted' } catch { if ($_.Exception.Message -eq 'Invalid email accepted') { throw } }
    try { New-TesterRecord -Email 'other@example.invalid' -Consent $false -DeviceModel x -AndroidVersion x -StorePath $store; throw 'Missing consent accepted' } catch { if ($_.Exception.Message -eq 'Missing consent accepted') { throw } }
    try { New-TesterRecord -Email 'tester@example.invalid' -Consent $true -DeviceModel x -AndroidVersion x -StorePath $store; throw 'Duplicate accepted' } catch { if ($_.Exception.Message -eq 'Duplicate accepted') { throw } }
    'TESTER_OPS_TESTS_PASS'
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

