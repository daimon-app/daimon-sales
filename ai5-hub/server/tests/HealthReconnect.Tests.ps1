$ErrorActionPreference='Stop'
function Assert-HR($Condition,[string]$Message){if(!$Condition){throw $Message}}
$appRoot=Split-Path (Split-Path $PSScriptRoot)
$app=Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'app.js')
$server=Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'server\server.ps1')
$command=Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'server\command-center\CommandCenter.ps1')
$launcher=Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'start-mobile.ps1')
$install=Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'install-autostart.ps1')
$sw=Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'service-worker.js')
Assert-HR ($app -match 'PCとAI5 Runtimeはオンラインです') 'status partial failure still promotes PC offline'
Assert-HR ($app -match "state.mode==='offline'\|\|state.statusDegraded") 'automatic reconnect / status retry probe missing'
Assert-HR ($app -match 'state.statusDegraded=true' -and $app -match 'state.statusDegraded=false') 'status degradation lifecycle missing'
Assert-HR ($app -match 'AI5 Runtimeへ再接続中') 'runtime-specific disconnected state missing'
Assert-HR ($server -match 'function Get-AI5MachineIdentity' -and $server -match "runtime = 'online'") 'machine/runtime health split missing'
Assert-HR ($command -match 'machine=\$mobileHealth.machine' -and $command -match 'components=\$mobileHealth') 'command-center health model missing'
Assert-HR ($launcher -match '\[switch\]\$Watch' -and $launcher -match 'watchdog restarting runtime') 'runtime watchdog missing'
Assert-HR ($install -match ' -Watch') 'autostart does not enable watchdog'
Assert-HR ($sw -match "const CACHE='ai5-hub-v[0-9]+-[^']+'" -and $sw -match 'if\(response.ok\)') 'versioned failed response cache protection missing'
'HEALTH_RECONNECT_TESTS_OK'
