<#
DAIMON Tool Executor: DASHBOARD (Owner-facing visualization of real DAIMON Node state)
Exact allowed operation : serve a read-only local HTTP dashboard showing the actual contents of
                          <bus_root> (tasks, worker-registry, leases). Never writes to the bus.
                          Separate from AI5HUB (profit-engine) - does not touch app.js/server.ps1
                          or port 43125, listens on its own port instead.
Input schema            : -Port <int> (default 43126), -BusRoot <path> (default the DAIMON bus root).
Path/scope restriction  : binds to http://127.0.0.1:<port>/ only (localhost, not 0.0.0.0); reads only
                          <bus_root>; serves only dashboard.html and /api/status - no other routes,
                          no file upload, no write endpoint of any kind.
Timeout                 : none - this is a long-running listener, not a one-shot tool. Stop with
                          Ctrl+C or by killing the process; it holds no lease and mutates nothing,
                          so killing it at any time is always safe.
Result/Receipt/Evidence : this tool itself has none (read-only view); the underlying data it
                          displays already has Result/Receipt/Evidence per DAIMON_WORKER_ROUTING_SPEC.md.
#>
param(
  [int]$Port = 43126,
  [string]$BusRoot = 'C:\Users\teppe\.local\daimon\bus',
  [string]$TailscaleIP = '100.72.31.31'
)
$ErrorActionPreference = 'Stop'
$htmlPath = Join-Path $PSScriptRoot 'dashboard.html'

function Get-StatusJson {
  $tasks = @()
  $tasksDir = Join-Path $BusRoot 'tasks'
  if (Test-Path -LiteralPath $tasksDir) {
    $tasks = Get-ChildItem -LiteralPath $tasksDir -Filter '*.json' -File | ForEach-Object {
      try { Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName | ConvertFrom-Json } catch { $null }
    } | Where-Object { $_ }
  }
  $registry = $null
  $registryPath = Join-Path $BusRoot 'worker-registry.json'
  if (Test-Path -LiteralPath $registryPath) {
    $registry = Get-Content -Raw -Encoding UTF8 -LiteralPath $registryPath | ConvertFrom-Json
  }
  $leases = @()
  $leaseDir = Join-Path $BusRoot 'leases'
  if (Test-Path -LiteralPath $leaseDir) {
    $leases = @(Get-ChildItem -LiteralPath $leaseDir -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
  }
  [ordered]@{
    generated_at   = [DateTimeOffset]::Now.ToString('o')
    tasks          = @($tasks | Select-Object task_id, status, selected_worker, blocker, output)
    worker_registry = $registry
    active_leases  = $leases
  } | ConvertTo-Json -Depth 12
}

# Also try the Tailscale interface so Owner devices already on the private tailnet (Galaxy, etc.)
# can view this read-only dashboard - never binds 0.0.0.0/public. Binding a specific non-localhost
# IP needs a urlacl reservation (HttpListener.Start() throws AccessDenied without one, even though
# Prefixes.Add() itself succeeds, and a failed Start() leaves the listener instance unusable -
# so build a fresh instance for the fallback rather than reuse the failed one).
$boundTailscale = $false
$listener = $null
if ($TailscaleIP) {
  $tryListener = New-Object System.Net.HttpListener
  $tryListener.Prefixes.Add("http://127.0.0.1:$Port/")
  $tryListener.Prefixes.Add("http://${TailscaleIP}:$Port/")
  try {
    $tryListener.Start()
    $listener = $tryListener
    $boundTailscale = $true
  } catch {
    Write-Output "Tailscale bind failed (needs 'netsh http add urlacl', not done automatically): $($_.Exception.Message)"
  }
}
if (-not $listener) {
  $listener = New-Object System.Net.HttpListener
  $listener.Prefixes.Add("http://127.0.0.1:$Port/")
  $listener.Start()
}
if ($boundTailscale) {
  Write-Output "DAIMON dashboard listening on http://127.0.0.1:$Port/ and http://${TailscaleIP}:$Port/ (Ctrl+C to stop; read-only, safe to kill anytime)"
} else {
  Write-Output "DAIMON dashboard listening on http://127.0.0.1:$Port/ only (Tailscale bind unavailable; localhost still works) - Ctrl+C to stop, safe to kill anytime"
}

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    try {
      if ($req.Url.AbsolutePath -eq '/api/status') {
        $body = [Text.Encoding]::UTF8.GetBytes((Get-StatusJson))
        $res.ContentType = 'application/json; charset=utf-8'
        $res.ContentLength64 = $body.Length
        $res.OutputStream.Write($body, 0, $body.Length)
      } elseif ($req.Url.AbsolutePath -eq '/' -or $req.Url.AbsolutePath -eq '/index.html') {
        $html = Get-Content -Raw -Encoding UTF8 -LiteralPath $htmlPath
        $body = [Text.Encoding]::UTF8.GetBytes($html)
        $res.ContentType = 'text/html; charset=utf-8'
        $res.ContentLength64 = $body.Length
        $res.OutputStream.Write($body, 0, $body.Length)
      } else {
        $res.StatusCode = 404
      }
    } catch {
      $res.StatusCode = 500
    } finally {
      $res.OutputStream.Close()
    }
  }
} finally {
  $listener.Stop()
  $listener.Close()
}
