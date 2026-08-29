param([switch]$Remove,[string]$StateRoot='')
$ErrorActionPreference = 'Stop'
$taskName = 'AI5 HUB Mobile'
$startupFile = Join-Path ([Environment]::GetFolderPath('Startup')) 'AI5 HUB Mobile.cmd'
if ($Remove) {
    schtasks.exe /Delete /TN $taskName /F 2>$null | Out-Null
    Remove-Item -LiteralPath $startupFile -Force -ErrorAction SilentlyContinue
    Write-Output 'AI5 HUB Mobile autostart removed.'
    exit
}
$script = Join-Path $PSScriptRoot 'start-mobile.ps1'
$powerShell = (Get-Command pwsh.exe -ErrorAction Stop).Source
$stateArgument=if($StateRoot){" -StateRoot `"$([IO.Path]::GetFullPath($StateRoot))`""}else{''}
$action = "`"$powerShell`" -NoProfile -ExecutionPolicy Bypass -File `"$script`"$stateArgument -Watch"
schtasks.exe /Create /TN $taskName /SC ONLOGON /TR $action /RL LIMITED /F 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { Remove-Item -LiteralPath $startupFile -Force -ErrorAction SilentlyContinue; Write-Output 'AI5 HUB Mobile autostart installed with Task Scheduler.'; exit }
$content="@echo off`r`nstart `"`" /min `"$powerShell`" -NoProfile -ExecutionPolicy Bypass -File `"$script`"$stateArgument -Watch`r`n"
Set-Content -LiteralPath $startupFile -Value $content -Encoding ASCII
if (!(Test-Path $startupFile)) { throw 'AI5 HUB autostart installation failed' }
Write-Output 'AI5 HUB Mobile autostart installed in the user Startup folder.'
