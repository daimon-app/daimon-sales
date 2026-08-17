param([switch]$Remove)
$ErrorActionPreference = 'Stop'
$taskName = 'AI5 HUB Mobile'
if ($Remove) {
    schtasks.exe /Delete /TN $taskName /F | Out-Null
    Write-Output 'AI5 HUB Mobile autostart removed.'
    exit
}
$script = Join-Path $PSScriptRoot 'start-mobile.ps1'
$powerShell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$action = "`"$powerShell`" -NoProfile -ExecutionPolicy Bypass -File `"$script`""
schtasks.exe /Create /TN $taskName /SC ONLOGON /TR $action /RL LIMITED /F | Out-Null
Write-Output 'AI5 HUB Mobile autostart installed for user logon.'
