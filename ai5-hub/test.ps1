$global:AI5TestRoot=Join-Path $PSScriptRoot 'server\tests'
$code=Get-Content -Raw -Encoding UTF8 (Join-Path $global:AI5TestRoot 'phase1.tests.ps1')
& ([ScriptBlock]::Create($code))
& (Join-Path $global:AI5TestRoot 'Phase2.Tests.ps1')
