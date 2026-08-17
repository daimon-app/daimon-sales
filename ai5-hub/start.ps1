param([int]$Port=43125,[string]$HostName='127.0.0.1')
$global:AI5ServerRoot=Join-Path $PSScriptRoot 'server'
$code=Get-Content -Raw -Encoding UTF8 (Join-Path $global:AI5ServerRoot 'server.ps1')
& ([ScriptBlock]::Create($code)) -Port $Port -HostName $HostName

