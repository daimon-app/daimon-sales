[CmdletBinding()]
param(
    [ValidateSet('Enroll','Daily','ExportTemplate')][string]$Action = 'Daily',
    [string]$StorePath,
    [string]$ExportPath
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'TesterOps.psm1') -Force

switch ($Action) {
    'Enroll' {
        $email = Read-Host 'Tester email (stored only in DPAPI-encrypted Git-external ledger)'
        $consentText = Read-Host 'Privacy consent confirmed? Type YES'
        $device = Read-Host 'Android device model'
        $android = Read-Host 'Android version'
        $version = Read-Host 'DAIMON app version (or UNVERIFIED)'
        $record = New-TesterRecord -Email $email -Consent ($consentText -ceq 'YES') -DeviceModel $device -AndroidVersion $android -AppVersion $version -StorePath $StorePath
        [pscustomobject]@{ Status='ENROLLED'; PseudonymousId=$record.PseudonymousId; Store=Get-DaimonTesterStorePath $StorePath }
    }
    'Daily' { Get-TesterDailySummary -StorePath $StorePath }
    'ExportTemplate' {
        if (-not $ExportPath) { throw '-ExportPath is required.' }
        [pscustomobject]@{ Status='EXPORTED_NON_PII_TEMPLATE'; Path=Export-TesterTemplate $ExportPath }
    }
}

