$appRoot = Split-Path (Split-Path $PSScriptRoot)
$manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'manifest.webmanifest') | ConvertFrom-Json
if ($manifest.id -ne 'https://laptop-32d9hni7.tail11672d.ts.net/' -or $manifest.scope -ne '/' -or $manifest.start_url -notlike '/*') { throw 'PWA id/scope/start_url invalid' }
if (@($manifest.related_applications | Where-Object { $_.platform -eq 'webapp' -and $_.id -eq $manifest.id }).Count -ne 1) { throw 'PWA self related_applications missing' }
if ($manifest.display -ne 'standalone') { throw 'PWA display must be standalone' }
foreach ($size in @(192, 512)) {
    $icon = @($manifest.icons | Where-Object { $_.sizes -eq "${size}x${size}" -and $_.type -eq 'image/png' })
    if ($icon.Count -lt 2) { throw "PWA requires any and maskable PNG icons at ${size}px" }
    $path = Join-Path $appRoot ($icon[0].src.TrimStart('/') -replace '/', '\')
    if (!(Test-Path $path)) { throw "Missing PWA icon: $path" }
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -lt 24 -or $bytes[0] -ne 137 -or $bytes[1] -ne 80 -or $bytes[2] -ne 78 -or $bytes[3] -ne 71) { throw "Invalid PNG: $path" }
    $width = [Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($bytes, 16))
    $height = [Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($bytes, 20))
    if ($width -ne $size -or $height -ne $size) { throw "Wrong PNG dimensions: $path" }
}
$worker = Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'service-worker.js')
if ($worker -notmatch "addEventListener\('fetch'" -or $worker -notmatch 'ai5-icon-192\.png' -or $worker -notmatch 'ai5-icon-512\.png') { throw 'Service worker PWA assets/fetch handler missing' }
$server = Get-Content -Raw -Encoding UTF8 (Join-Path $appRoot 'server\server.ps1')
if ($server -notmatch "'\.png'\s*=\s*'image/png'") { throw 'PNG MIME mapping missing' }
'PWA_INSTALLABILITY_TESTS_OK'
