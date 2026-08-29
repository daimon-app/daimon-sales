$ErrorActionPreference = 'Stop'

$adapterName = (Get-NetAdapter |
    Where-Object InterfaceDescription -EQ 'Realtek PCIe GbE Family Controller' |
    Select-Object -First 1 -ExpandProperty Name)
if (-not $adapterName) {
    throw 'Realtek PCIe GbE Family Controller was not found.'
}
$logPath = Join-Path $PSScriptRoot '..\diagnostics\wol-settings-after-20260818.txt'

try {
    Set-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword '*EEE' -RegistryValue 0 -NoRestart
    Set-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword 'EnableGreenEthernet' -RegistryValue 0 -NoRestart
    Set-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword 'PowerSavingMode' -RegistryValue 0 -NoRestart
    Set-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword '*WakeOnMagicPacket' -RegistryValue 1 -NoRestart
    Set-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword 'S5WakeOnLan' -RegistryValue 1 -NoRestart
    Set-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword '*WakeOnPattern' -RegistryValue 0 -NoRestart

    Set-ItemProperty `
        -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' `
        -Name HiberbootEnabled `
        -Type DWord `
        -Value 0

    powercfg.exe -deviceenablewake 'Realtek PCIe GbE Family Controller'
    if ($LASTEXITCODE -ne 0) {
        throw "powercfg -deviceenablewake failed with exit code $LASTEXITCODE"
    }

    Restart-NetAdapter -Name $adapterName
    Start-Sleep -Seconds 5

    $lines = @(
        "Applied: $(Get-Date -Format o)"
        'Adapter settings:'
        (Get-NetAdapterAdvancedProperty -Name $adapterName -AllProperties |
            Where-Object RegistryKeyword -In @(
                '*EEE',
                'EnableGreenEthernet',
                'PowerSavingMode',
                '*WakeOnMagicPacket',
                'S5WakeOnLan',
                '*WakeOnPattern',
                'WolShutdownLinkSpeed'
            ) |
            Select-Object DisplayName, DisplayValue, RegistryKeyword, RegistryValue |
            Format-Table -AutoSize |
            Out-String)
        "HiberbootEnabled: $((Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled).HiberbootEnabled)"
        'wake_armed:'
        (powercfg.exe /devicequery wake_armed | Out-String)
        'Adapter:'
        (Get-NetAdapter -Name $adapterName | Select-Object Status, LinkSpeed, MacAddress | Format-List | Out-String)
        'RESULT=PASS'
    )
    $lines | Set-Content -LiteralPath $logPath -Encoding UTF8
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
