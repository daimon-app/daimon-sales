Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AllowedInvite = @('DRAFT','OWNER_APPROVED','SENT','OPTED_IN','DECLINED','WITHDRAWN')
$script:AllowedResult = @('PASS','FAIL','PARTIAL','UNVERIFIED','BLOCKED')
$script:AllowedSeverity = @('P0','P1','P2','P3','NONE')
$script:AllowedFix = @('NEW','TRIAGED','IN_PROGRESS','FIXED_PENDING_RETEST','VERIFIED','WONT_FIX_WITH_REASON','NONE')

function Get-DaimonTesterStorePath {
    param([string]$StorePath)
    if ($StorePath) { return [IO.Path]::GetFullPath($StorePath) }
    if (-not $env:LOCALAPPDATA) { throw 'LOCALAPPDATA is unavailable.' }
    return Join-Path $env:LOCALAPPDATA 'DAIMON\tester-ops\ledger.dpapi'
}

function Assert-StoreOutsideGit {
    param([Parameter(Mandatory)][string]$StorePath)
    $full = [IO.Path]::GetFullPath($StorePath)
    $cursor = Split-Path -Parent $full
    while ($cursor) {
        if (Test-Path -LiteralPath (Join-Path $cursor '.git')) {
            throw 'Tester PII store must be outside every Git worktree.'
        }
        $parent = Split-Path -Parent $cursor
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Protect-LedgerText {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $protected = [Security.Cryptography.ProtectedData]::Protect(
        $bytes, [Text.Encoding]::UTF8.GetBytes('DAIMON-TESTER-OPS-v1'),
        [Security.Cryptography.DataProtectionScope]::CurrentUser)
    return [Convert]::ToBase64String($protected)
}

function Unprotect-LedgerText {
    param([Parameter(Mandatory)][string]$CipherText)
    $bytes = [Convert]::FromBase64String($CipherText)
    $plain = [Security.Cryptography.ProtectedData]::Unprotect(
        $bytes, [Text.Encoding]::UTF8.GetBytes('DAIMON-TESTER-OPS-v1'),
        [Security.Cryptography.DataProtectionScope]::CurrentUser)
    return [Text.Encoding]::UTF8.GetString($plain)
}

function Read-TesterLedger {
    param([string]$StorePath)
    $path = Get-DaimonTesterStorePath $StorePath
    Assert-StoreOutsideGit $path
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    $cipher = Get-Content -Raw -LiteralPath $path
    if (-not $cipher) { throw 'Encrypted ledger is empty.' }
    $items = Unprotect-LedgerText $cipher | ConvertFrom-Json
    return @($items)
}

function Write-TesterLedger {
    param([Parameter(Mandatory)][array]$Records,[string]$StorePath)
    $path = Get-DaimonTesterStorePath $StorePath
    Assert-StoreOutsideGit $path
    $dir = Split-Path -Parent $path
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $json = ConvertTo-Json $Records -Depth 8 -Compress
    $cipher = Protect-LedgerText $json
    [IO.File]::WriteAllText($path, $cipher, [Text.UTF8Encoding]::new($false))
    return $path
}

function Test-TesterRecord {
    param([Parameter(Mandatory)]$Record)
    if ($Record.Email -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'Invalid email address.' }
    if ($Record.Consent -ne $true) { throw 'Explicit privacy consent is required.' }
    if ($Record.PseudonymousId -notmatch '^T-[A-Z0-9]{8,32}$') { throw 'Invalid pseudonymous ID.' }
    if ($Record.InviteState -notin $script:AllowedInvite) { throw 'Invalid invite state.' }
    if ($Record.CoreQa -notin $script:AllowedResult -or $Record.BillingQa -notin $script:AllowedResult) { throw 'Invalid QA state.' }
    if ($Record.Severity -notin $script:AllowedSeverity -or $Record.FixState -notin $script:AllowedFix) { throw 'Invalid triage state.' }
    foreach ($forbidden in @('Password','Otp','PurchaseToken','PaymentCredential','GovernmentId')) {
        if ($Record.PSObject.Properties.Name -contains $forbidden) { throw "Forbidden tester field: $forbidden" }
    }
    return $true
}

function New-TesterRecord {
    param(
        [Parameter(Mandatory)][string]$Email,
        [Parameter(Mandatory)][bool]$Consent,
        [Parameter(Mandatory)][string]$DeviceModel,
        [Parameter(Mandatory)][string]$AndroidVersion,
        [string]$AppVersion = 'UNVERIFIED',
        [string]$StorePath
    )
    $id = 'T-' + ([guid]::NewGuid().ToString('N').Substring(0,12).ToUpperInvariant())
    $now = [DateTimeOffset]::Now.ToString('o')
    $record = [pscustomobject]@{
        SchemaVersion = 1; PseudonymousId = $id; Email = $Email.Trim(); Consent = $Consent
        ConsentTimestamp = $now; DeviceModel = $DeviceModel.Trim(); AndroidVersion = $AndroidVersion.Trim()
        AppVersion = $AppVersion.Trim(); InviteState = 'DRAFT'; Install = 'UNVERIFIED'
        CoreQa = 'UNVERIFIED'; BillingQa = 'UNVERIFIED'; Severity = 'NONE'; FixState = 'NONE'
        LastContact = $null; DeleteBy = $null; CreatedAt = $now; UpdatedAt = $now
    }
    Test-TesterRecord $record | Out-Null
    $records = @(Read-TesterLedger $StorePath)
    if (@($records | Where-Object { $_.Email -eq $record.Email }).Count -gt 0) { throw 'Duplicate tester email.' }
    Write-TesterLedger -Records @($records + $record) -StorePath $StorePath | Out-Null
    return $record
}

function Get-TesterDailySummary {
    param([string]$StorePath)
    $records = @(Read-TesterLedger $StorePath)
    [pscustomobject]@{
        GeneratedAt = [DateTimeOffset]::Now.ToString('o')
        Total = $records.Count
        OptedIn = @($records | Where-Object InviteState -eq 'OPTED_IN').Count
        P0 = @($records | Where-Object Severity -eq 'P0').Count
        P1 = @($records | Where-Object Severity -eq 'P1').Count
        NeedsRetest = @($records | Where-Object FixState -eq 'FIXED_PENDING_RETEST').Count
        DeletionDue = @($records | Where-Object { $_.DeleteBy -and ([DateTimeOffset]$_.DeleteBy) -le [DateTimeOffset]::Now }).Count
    }
}

function Export-TesterTemplate {
    param([Parameter(Mandatory)][string]$Path)
    $headers = 'PseudonymousId,InviteState,DeviceModel,AndroidVersion,AppVersion,Install,CoreQa,BillingQa,Severity,FixState,CreatedAt,UpdatedAt'
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($Path), $headers + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    return [IO.Path]::GetFullPath($Path)
}

Export-ModuleMember -Function Get-DaimonTesterStorePath,Read-TesterLedger,Write-TesterLedger,Test-TesterRecord,New-TesterRecord,Get-TesterDailySummary,Export-TesterTemplate
