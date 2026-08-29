$ErrorActionPreference = 'Stop'

$subSleep = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
$unattendedSleep = '7bc4a2f9-d8fc-4469-b07b-33eb785aaca0'
$logPath = Join-Path $PSScriptRoot '..\diagnostics\unattended-sleep-after-20260818.txt'

try {
    powercfg.exe /setacvalueindex SCHEME_CURRENT $subSleep $unattendedSleep 0
    if ($LASTEXITCODE -ne 0) {
        throw "powercfg setacvalueindex failed with exit code $LASTEXITCODE"
    }
    powercfg.exe /setactive SCHEME_CURRENT
    if ($LASTEXITCODE -ne 0) {
        throw "powercfg setactive failed with exit code $LASTEXITCODE"
    }

    $schemeLine = powercfg.exe /getactivescheme
    $schemeGuid = [regex]::Match(($schemeLine | Out-String), '[0-9a-fA-F-]{36}').Value
    $valuePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$schemeGuid\$subSleep\$unattendedSleep"
    $value = Get-ItemProperty -LiteralPath $valuePath

    @(
        "Applied: $(Get-Date -Format o)"
        "Scheme: $schemeGuid"
        "ACSettingIndex: $($value.ACSettingIndex)"
        "DCSettingIndex: $($value.DCSettingIndex)"
        'RESULT=PASS'
    ) | Set-Content -LiteralPath $logPath -Encoding UTF8
    exit 0
}
catch {
    @(
        "Failed: $(Get-Date -Format o)"
        $_.Exception.ToString()
        'RESULT=FAIL'
    ) | Set-Content -LiteralPath $logPath -Encoding UTF8
    exit 1
}
