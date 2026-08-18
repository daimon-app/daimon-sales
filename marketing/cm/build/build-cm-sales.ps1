[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$ffmpeg=(Get-ChildItem (Join-Path $root '.tools\ffmpeg') -Recurse -Filter ffmpeg.exe | Select-Object -First 1 -ExpandProperty FullName)
if(-not $ffmpeg){throw 'FFmpeg not found. Run setup-ffmpeg.ps1 first.'}
$shots=Join-Path $root 'marketing\play-store\screenshots'
$assets=Join-Path $root 'marketing\cm\assets'
$exports=Join-Path $root 'marketing\cm\exports'

function Build-Sequence([string]$name,[array]$sequence){
  $args=@('-y')
  foreach($item in $sequence){$args+=@('-loop','1','-t',[string]$item.Seconds,'-i',[string]$item.Path)}
  $parts=@();$labels=@()
  for($i=0;$i -lt $sequence.Count;$i++){$parts+="[$i`:v]scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black,fps=30,format=yuv420p,setsar=1[v$i]";$labels+="[v$i]"}
  $filter=($parts -join ';')+';'+($labels -join '')+"concat=n=$($sequence.Count):v=1:a=0[outv]"
  $out=Join-Path $exports $name
  & $ffmpeg @args -filter_complex $filter -map '[outv]' -c:v libx264 -profile:v high -level 4.1 -pix_fmt yuv420p -r 30 -movflags +faststart -an $out
  if($LASTEXITCODE -ne 0){throw "FFmpeg failed: $name"}
}

$hook=Join-Path $assets 'card-hook.png';$facts=Join-Path $assets 'card-facts.png';$cta=Join-Path $assets 'card-cta.png'
$start=Join-Path $shots '01-start.png';$breath=Join-Path $shots '02-breath.png';$morning=Join-Path $shots '03-morning.png';$finish=Join-Path $shots '04-finish.png'

Build-Sequence 'cm-a-teaser-1080x1920.mp4' @(@{Path=$hook;Seconds=2.5},@{Path=$morning;Seconds=2.5},@{Path=$cta;Seconds=2})
Build-Sequence 'cm-b-product-flow-1080x1920.mp4' @(@{Path=$hook;Seconds=2},@{Path=$start;Seconds=2.5},@{Path=$breath;Seconds=2.5},@{Path=$morning;Seconds=5},@{Path=$finish;Seconds=3})
Build-Sequence 'cm-c-purchase-1080x1920.mp4' @(@{Path=$facts;Seconds=4},@{Path=$start;Seconds=2},@{Path=$breath;Seconds=2},@{Path=$morning;Seconds=5},@{Path=$finish;Seconds=3},@{Path=$cta;Seconds=5})
