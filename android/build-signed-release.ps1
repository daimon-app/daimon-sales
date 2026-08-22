[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
$workspaceRoot=Split-Path (Split-Path $repoRoot -Parent) -Parent
$signingRoot=Join-Path $env:LOCALAPPDATA 'DAIMON\signing'
$keystore=Join-Path $signingRoot 'daimon-upload.jks'
$storeBlob=Join-Path $signingRoot 'store-password.dpapi'
$keyBlob=Join-Path $signingRoot 'key-password.dpapi'
foreach($path in @($keystore,$storeBlob,$keyBlob)){if(!(Test-Path -LiteralPath $path)){throw "Missing protected signing input: $path"}}
function Read-Dpapi([string]$Path){$secure=ConvertTo-SecureString (Get-Content -LiteralPath $Path -Raw);([pscredential]::new('daimon',$secure)).GetNetworkCredential().Password}
$env:DAIMON_UPLOAD_STORE_FILE=$keystore
$env:DAIMON_UPLOAD_STORE_PASSWORD=Read-Dpapi $storeBlob
$env:DAIMON_UPLOAD_KEY_ALIAS='daimon-upload'
$env:DAIMON_UPLOAD_KEY_PASSWORD=Read-Dpapi $keyBlob
$env:JAVA_HOME=Join-Path $workspaceRoot 'zero-wake-pc\.tools\jdk\jdk-17.0.20+8'
$env:ANDROID_HOME=Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$env:ANDROID_USER_HOME=Join-Path $workspaceRoot '.android-user'
$env:GRADLE_USER_HOME=Join-Path $workspaceRoot '.gradle-user'
try{
  & (Join-Path $PSScriptRoot 'gradlew.bat') --no-daemon clean testDebugUnitTest bundleRelease
  if($LASTEXITCODE){throw "Gradle failed: $LASTEXITCODE"}
  $aab=Join-Path $PSScriptRoot 'app\build\outputs\bundle\release\app-release.aab'
  & (Join-Path $env:JAVA_HOME 'bin\jarsigner.exe') -verify -verbose -certs $aab | Out-Null
  if($LASTEXITCODE){throw 'AAB signature verification failed'}
  [ordered]@{status='PASS';artifact=$aab;sha256=(Get-FileHash $aab -Algorithm SHA256).Hash;certificate_sha256='1E:9E:96:A5:82:F2:9A:FA:FE:D0:E9:49:20:FE:16:40:2D:90:28:33:E9:86:01:B0:B3:36:76:DE:76:EF:1B:8D'}|ConvertTo-Json
}finally{
  Remove-Item Env:DAIMON_UPLOAD_STORE_FILE,Env:DAIMON_UPLOAD_STORE_PASSWORD,Env:DAIMON_UPLOAD_KEY_ALIAS,Env:DAIMON_UPLOAD_KEY_PASSWORD -ErrorAction SilentlyContinue
}
