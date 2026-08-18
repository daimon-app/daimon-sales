$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$failures=[Collections.Generic.List[string]]::new()
function Check([bool]$ok,[string]$name){if($ok){Write-Host "PASS $name" -ForegroundColor Green}else{Write-Host "FAIL $name" -ForegroundColor Red;$failures.Add($name)}}
function Decode([string]$b64){[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))}
$lp=[IO.File]::ReadAllText((Join-Path $repo 'marketing/lp/index.html'),[Text.Encoding]::UTF8)
$posts=[IO.File]::ReadAllText((Join-Path $repo 'marketing/social/posts-30.md'),[Text.Encoding]::UTF8)
$utm=[IO.File]::ReadAllText((Join-Path $repo 'marketing/analytics/utm-rules.md'),[Text.Encoding]::UTF8)
$feature=[IO.File]::ReadAllText((Join-Path $repo 'marketing/play-store/feature-graphic/feature-graphic.svg'),[Text.Encoding]::UTF8)
$release=[IO.File]::ReadAllText((Join-Path $repo 'marketing/lp/release-config.js'),[Text.Encoding]::UTF8)
$cmScripts=[IO.File]::ReadAllText((Join-Path $repo 'marketing/cm/scripts/cm-master.md'),[Text.Encoding]::UTF8)
$video=Join-Path $repo 'marketing/cm/exports/cm-a-morning-1080x1920.mp4'
Check (([regex]::Matches($posts,'(?m)^\d+\.')).Count -eq 30) 'post count = 30'
Check ($lp.Contains('DAIMON MORNING Edition')) 'LP product name'
foreach($b64 in @('NDkw5YaG','6LK344GE5YiH44KK','5bqD5ZGK44Gq44GX','QW5kcm9pZOWIneeJiA==')){Check ($lp.Contains((Decode $b64))) "LP required sales term $b64"}
foreach($href in @('privacy.html','terms.html','legal.html','contact.html')){Check ($lp.Contains("href=`"$href`"")) "LP link $href";Check (Test-Path (Join-Path $repo "marketing/lp/$href")) "file $href"}
Check (-not $lp.Contains('DAIMON sales edition')) 'old English name absent'
Check ($feature -match 'width="1024"' -and $feature -match 'height="500"') 'feature graphic 1024x500'
$featurePng=Join-Path $repo 'marketing/play-store/feature-graphic/feature-graphic.png'
Check ((Test-Path $featurePng) -and ((Get-Item $featurePng).Length -gt 1000)) 'feature graphic PNG exists'
Check (-not $feature.Contains((Decode 'NDkw5YaG'))) 'feature graphic excludes price promotion'
$playIcon=Join-Path $repo 'marketing/play-store/icon/icon-512.png'
Check ((Test-Path $playIcon) -and ((Get-Item $playIcon).Length -gt 1000)) 'Play icon exists'
foreach($term in @('utm_source','utm_medium','utm_campaign','utm_content','p01','p30','cm-a','cm-e')){Check ($utm.Contains($term)) "UTM $term"}
Check ($release.Contains('state: "prelaunch"')) 'release config defaults to prelaunch'
Check ($release.Contains('playStoreUrl: ""')) 'Play URL is empty before approval'
Check (-not $posts.Contains((Decode '77yP5LuV5LqL55S76Z2i'))) 'posts exclude work screen promise'
Check (-not $posts.Contains((Decode '6Ieq5YiG44Gu5pmv6Imy44Gr5pu/44GI44KJ44KM44KL'))) 'posts exclude unsupported customization'
Check ($cmScripts.Contains((Decode 'TW9ybmluZ+WwgueUqENNLUM='))) 'CM-C is Morning-only'
Check (Test-Path (Join-Path $repo 'marketing/brand/asset-rights-ledger.csv')) 'asset rights ledger exists'
Check (Test-Path (Join-Path $repo 'marketing/release-gates.md')) 'release gate register exists'
Check (Test-Path $video) 'CM-A exists'
$ffprobe=(Get-ChildItem (Join-Path $repo '.tools/ffmpeg') -Recurse -Filter ffprobe.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if($ffprobe -and (Test-Path $video)){$json=& $ffprobe -v error -show_entries format=duration,format_name:stream=codec_name,width,height,r_frame_rate -of json $video | ConvertFrom-Json;$s=$json.streams[0];Check ($s.width -eq 1080 -and $s.height -eq 1920) 'CM-A resolution';Check ($s.codec_name -eq 'h264') 'CM-A H.264';Check ($s.r_frame_rate -eq '30/1') 'CM-A 30fps';Check ([Math]::Abs([double]$json.format.duration-7.0) -lt 0.05) 'CM-A 7 seconds'}else{Check $false 'ffprobe available'}
$trackedText=Get-ChildItem (Join-Path $repo 'marketing') -Recurse -File | Where-Object Extension -in '.md','.html','.css','.ps1','.cmd','.csv','.svg' | ForEach-Object {[IO.File]::ReadAllText($_.FullName)}
Check (-not(($trackedText -join "`n") -match '(?i)(api[_-]?key|client[_-]?secret|password)\s*[:=]\s*["''][^"'']{8,}')) 'no obvious secrets'
if($failures.Count){Write-Error ("Marketing QA failed: "+($failures -join ', '));exit 1}
Write-Host 'MARKETING_QA_PASS' -ForegroundColor Green
