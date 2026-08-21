param([int]$Port = 43125,[string]$StateRoot = '',[switch]$Watch)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$resolvedStateRoot = if($StateRoot){[IO.Path]::GetFullPath($StateRoot)}else{Join-Path $root 'server'}
$env:AI5_STATE_ROOT=$resolvedStateRoot
$logRoot = Join-Path $resolvedStateRoot 'logs\remote_access'
New-Item -ItemType Directory -Force $logRoot | Out-Null
$log = Join-Path $logRoot ((Get-Date).ToString('yyyy-MM-dd') + '.log')
function Write-MobileLog($message) { Add-Content -LiteralPath $log -Encoding UTF8 -Value "$(Get-Date -Format o) $message" }

function Start-AI5HubRuntime {
    $alreadyRunning = $false
    try { $alreadyRunning = [bool](Invoke-RestMethod "http://127.0.0.1:$Port/api/health" -TimeoutSec 2).ok } catch {}
    if ($alreadyRunning) { return }
    $powerShell = (Get-Command pwsh.exe -ErrorAction Stop).Source
    $startScript = Join-Path $root 'start.ps1'
    Start-Process -FilePath $powerShell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$startScript,'-Port',$Port) -WindowStyle Hidden
    $ready = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 500
        try { if ((Invoke-RestMethod "http://127.0.0.1:$Port/api/session").authenticated) { $ready = $true; break } } catch {}
    }
    if (!$ready) { Write-MobileLog 'AI5 HUB start failed'; throw 'AI5 HUB did not become ready' }
    Write-MobileLog 'AI5 HUB started'
}
Start-AI5HubRuntime

$tailscaleCommand = Get-Command tailscale -ErrorAction SilentlyContinue
$tailscalePath = if ($tailscaleCommand) { $tailscaleCommand.Source } else { $null }
if (!$tailscalePath) {
    $candidate = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (Test-Path $candidate) { $tailscalePath = $candidate }
}
if (!$tailscalePath) { Write-MobileLog 'Tailscale unavailable'; throw 'Tailscale is not installed' }

$status = & $tailscalePath status --json 2>$null | ConvertFrom-Json
if ($status.BackendState -ne 'Running') { Write-MobileLog 'Tailscale authentication required'; throw 'Tailscale is not authenticated' }
& $tailscalePath serve --bg "http://127.0.0.1:$Port" | Out-Null
if ($LASTEXITCODE -ne 0) { Write-MobileLog 'Tailscale Serve failed'; throw 'Tailscale Serve failed' }
Write-MobileLog 'Tailscale Serve active'
& $tailscalePath serve status

if ($Watch) {
    Write-MobileLog 'AI5 HUB watchdog active'
    $failures = 0
    while ($true) {
        Start-Sleep -Seconds 5
        try {
            if ((Invoke-RestMethod "http://127.0.0.1:$Port/api/health" -TimeoutSec 3).ok) { $failures = 0; continue }
        } catch {}
        $failures++
        if ($failures -lt 3) { continue }
        Write-MobileLog 'AI5 HUB watchdog restarting runtime'
        try { Start-AI5HubRuntime; $failures = 0 } catch { Write-MobileLog "AI5 HUB watchdog restart failed: $($_.Exception.Message)" }
    }
}
