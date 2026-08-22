[CmdletBinding()]
param([string]$EvidenceRoot=(Join-Path $PSScriptRoot 'evidence-connected'))
$ErrorActionPreference='Stop'
$adb=Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if(!(Test-Path $adb)){throw 'ADB_NOT_FOUND'}
$devices=@(& $adb devices|Select-Object -Skip 1|Where-Object{$_ -match '\tdevice$'})
if($devices.Count-ne1){throw "EXPECTED_EXACTLY_ONE_AUTHORIZED_DEVICE; found=$($devices.Count)"}
New-Item -ItemType Directory -Path $EvidenceRoot -Force|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss';$out=Join-Path $EvidenceRoot $stamp;New-Item -ItemType Directory -Path $out|Out-Null
& $adb shell getprop ro.product.manufacturer|Set-Content (Join-Path $out 'manufacturer.txt')
& $adb shell getprop ro.product.model|Set-Content (Join-Path $out 'model.txt')
& $adb shell getprop ro.build.version.sdk|Set-Content (Join-Path $out 'api-level.txt')
& $adb logcat -c
& $adb shell am force-stop app.daimon
& $adb shell monkey -p app.daimon -c android.intent.category.LAUNCHER 1|Set-Content (Join-Path $out 'launch.txt')
Start-Sleep -Seconds 3
& $adb exec-out screencap -p > (Join-Path $out 'launch.png')
& $adb shell dumpsys meminfo app.daimon|Set-Content (Join-Path $out 'meminfo.txt')
& $adb logcat -d '*:E'|Set-Content (Join-Path $out 'logcat-errors.txt')
if((Get-Content (Join-Path $out 'logcat-errors.txt') -Raw)-match 'FATAL EXCEPTION|ANR in app\.daimon'){throw 'CRASH_OR_ANR_DETECTED'}
[ordered]@{status='PARTIAL_PASS';device_count=1;evidence=$out;manual_audio_binaural_and_purchase_checks='REQUIRED'}|ConvertTo-Json
