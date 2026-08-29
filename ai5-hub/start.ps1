param([int]$Port=43125,[string]$HostName='127.0.0.1')
$global:AI5CodeServerRoot=Join-Path $PSScriptRoot 'server'
$global:AI5ServerRoot=if($env:AI5_STATE_ROOT){[IO.Path]::GetFullPath($env:AI5_STATE_ROOT)}else{$global:AI5CodeServerRoot}
$code=Get-Content -Raw -Encoding UTF8 (Join-Path $global:AI5CodeServerRoot 'server.ps1')
& ([ScriptBlock]::Create($code)) -Port $Port -HostName $HostName

