[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidatePattern('^https://')][string]$BaseUrl,
  [ValidateSet('prelaunch','launch','evergreen')][string]$Campaign='prelaunch'
)
$ErrorActionPreference='Stop'
$sources=@('tiktok','instagram','youtube','threads','x','facebook','pinterest')
$contents=@('profile','pinned')+(1..30|ForEach-Object{'p{0:d2}'-f $_})+@('cm-a','cm-b','cm-c')
$rows=foreach($source in $sources){foreach($content in $contents){
  $query='utm_source={0}&utm_medium=organic_social&utm_campaign={1}&utm_content={2}'-f $source,$Campaign,$content
  [pscustomobject]@{source=$source;medium='organic_social';campaign=$Campaign;content=$content;url="$($BaseUrl.TrimEnd('/'))/?$query"}
}}
$rows|Export-Csv (Join-Path $PSScriptRoot 'generated-links.csv') -NoTypeInformation -Encoding utf8
Write-Host "Generated $($rows.Count) links: marketing/analytics/generated-links.csv"
