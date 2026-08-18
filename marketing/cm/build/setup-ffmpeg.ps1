$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$toolRoot=Join-Path $repo '.tools'
$zip=Join-Path $toolRoot 'ffmpeg-release-essentials.zip'
$extract=Join-Path $toolRoot 'ffmpeg'
New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null
Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile $zip
Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
$ffmpeg=Get-ChildItem $extract -Recurse -Filter ffmpeg.exe | Select-Object -First 1
if(-not $ffmpeg){throw 'FFmpeg extraction failed.'}
& $ffmpeg.FullName -version | Select-Object -First 1
