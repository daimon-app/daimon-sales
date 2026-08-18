[CmdletBinding()]
param([string]$Output)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$work=Join-Path $PSScriptRoot 'work'
$assets=Join-Path $repo 'marketing/cm/assets'
$exports=Join-Path $repo 'marketing/cm/exports'
New-Item -ItemType Directory -Force -Path $work,$assets,$exports | Out-Null
if(-not $Output){$Output=Join-Path $exports 'cm-a-morning-1080x1920.mp4'}

$ffmpeg=(Get-ChildItem (Join-Path $repo '.tools/ffmpeg') -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if(-not $ffmpeg){throw 'FFmpeg not found. Run setup-ffmpeg.ps1 first.'}
$font='C:/Windows/Fonts/YuGothB.ttc'
if(-not(Test-Path $font)){$font='C:/Windows/Fonts/BIZ-UDGothicB.ttc'}
if(-not(Test-Path $font)){throw 'Japanese font not found.'}

$app=Get-Content -Raw (Join-Path $repo 'index.html')
$match=[regex]::Match($app,'"morning01":"data:image/jpeg;base64,([^\"]+)"')
if(-not $match.Success){throw 'morning01 official image was not found in index.html.'}
$morning=Join-Path $assets 'morning01.jpg'
[IO.File]::WriteAllBytes($morning,[Convert]::FromBase64String($match.Groups[1].Value))

$t1=Join-Path $work '01.txt';$t2=Join-Path $work '02.txt';$t3=Join-Path $work '03.txt';$t4=Join-Path $work '04.txt'
[IO.File]::WriteAllBytes($t1,[Convert]::FromBase64String('44G+44Gf44CB44K644Os44Gf44CC'))
[IO.File]::WriteAllBytes($t2,[Convert]::FromBase64String('44K644Os44Gf44KJ44CB5oi744KM44Gw44GE44GE44CC'))
[IO.File]::WriteAllText($t3,'DAIMON MORNING Edition',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllBytes($t4,[Convert]::FromBase64String('R29vZ2xlIFBsYXnjgafov5Hml6Xlhazplos='))
$f=(($font -replace '\\','/') -replace ':','\:')
$q={param($p) (($p -replace '\\','/') -replace ':','\:')}
$filter="[0:v]scale=1080:1920:force_original_aspect_ratio=increase:in_range=full:out_range=tv,crop=1080:1920,boxblur=8:2,eq=brightness=-0.34:saturation=0.72,drawbox=x=390:y=500:w=300:h=300:color=0x151515@0.92:t=fill:enable='between(t,4.8,7)',drawbox=x=390:y=500:w=300:h=300:color=0xD8B46A@1:t=4:enable='between(t,4.8,7)',drawtext=fontfile='$f':text='D':fontcolor=0xD8B46A:fontsize=150:x=(w-text_w)/2:y=555:enable='between(t,4.8,7)',drawtext=fontfile='$f':textfile='$(& $q $t1)':fontcolor=white:fontsize=82:x=(w-text_w)/2:y=760:enable='between(t,0,1.5)':alpha='if(lt(t,0.25),t/0.25,if(gt(t,1.2),(1.5-t)/0.3,1))',drawtext=fontfile='$f':textfile='$(& $q $t2)':fontcolor=white:fontsize=72:x=(w-text_w)/2:y=790:enable='between(t,1.5,4.8)',drawtext=fontfile='$f':textfile='$(& $q $t3)':fontcolor=0xF6F1E7:fontsize=48:x=(w-text_w)/2:y=850:enable='between(t,4.8,7)',drawtext=fontfile='$f':textfile='$(& $q $t4)':fontcolor=0xD8B46A:fontsize=36:x=(w-text_w)/2:y=935:enable='between(t,4.8,7)',fade=t=in:st=0:d=0.25,fade=t=out:st=6.65:d=0.35,format=yuv420p,setparams=range=limited[out]"
& $ffmpeg -y -loop 1 -framerate 30 -i $morning -filter_complex $filter -map '[out]' -t 7 -an -r 30 -c:v libx264 -profile:v high -level 4.1 -preset medium -crf 18 -movflags +faststart $Output
if($LASTEXITCODE -ne 0){throw "FFmpeg failed: $LASTEXITCODE"}
Write-Output $Output
