[CmdletBinding()]
param([ValidateRange(1024,65535)][int]$Port=4173,[switch]$NoBrowser)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($PSScriptRoot)
$url="http://127.0.0.1:$Port/"
$mime=@{'.html'='text/html; charset=utf-8';'.css'='text/css; charset=utf-8';'.js'='text/javascript; charset=utf-8';'.svg'='image/svg+xml';'.png'='image/png';'.jpg'='image/jpeg';'.jpeg'='image/jpeg';'.webp'='image/webp';'.mp4'='video/mp4'}
$server=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$Port)
try{
  $server.Start();Write-Host "DAIMON marketing preview: $url";Write-Host 'Press Ctrl+C to stop.'
  if(-not $NoBrowser){Start-Process $url}
  while($true){
    $client=$server.AcceptTcpClient()
    try{
      $stream=$client.GetStream();$reader=[IO.StreamReader]::new($stream,[Text.Encoding]::ASCII,$false,1024,$true)
      $request=$reader.ReadLine();while(($line=$reader.ReadLine()) -ne $null -and $line -ne ''){}
      $target=if($request -match '^GET\s+([^\s]+)\s+HTTP/'){$Matches[1]}else{'/'}
      $path=([Uri]::new("http://localhost$target")).AbsolutePath.TrimStart('/');if(-not $path){$path='index.html'}
      $candidate=[IO.Path]::GetFullPath((Join-Path $root ([Uri]::UnescapeDataString($path))))
      if(-not $candidate.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Invalid path'}
      if(Test-Path -LiteralPath $candidate -PathType Leaf){$status='200 OK';$body=[IO.File]::ReadAllBytes($candidate);$ext=[IO.Path]::GetExtension($candidate).ToLowerInvariant();$type=if($mime.ContainsKey($ext)){$mime[$ext]}else{'application/octet-stream'}}else{$status='404 Not Found';$body=[Text.Encoding]::UTF8.GetBytes('404 Not Found');$type='text/plain; charset=utf-8'}
      $header=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nConnection: close`r`nCache-Control: no-store`r`n`r`n")
      $stream.Write($header,0,$header.Length);$stream.Write($body,0,$body.Length);$stream.Flush()
    }catch{}finally{$client.Close()}
  }
}finally{$server.Stop()}
