<#
DAIMON Tool Executor: REMOTE_STATUS
Exact allowed operation : read-only DAIMON Remote host diagnostics - hostname, process counts for a
                          FIXED name list, service state for a FIXED service list, local TCP 21118
                          listen state, and TCP reachability probes to the FIXED dynabook and Galaxy
                          private Tailscale endpoints. Never reads command lines, window titles, config files, or secrets.
Input schema            : none except -BusRoot (output directory). No task-specific input accepted.
Path/scope restriction  : read-only Get-Process / Get-Service / Get-NetTCPConnection plus one outbound
                          TCP connect (no payload sent); writes only
                          <bus_root>\results\REMOTE_STATUS-<timestamp>.json.
Timeout                 : TCP probe 3 s; everything else synchronous local queries.
Exit codes              : 0 = report written (probe failures are reported as data, not errors).
Result/Receipt/Evidence : writes <bus_root>\results\REMOTE_STATUS-<timestamp>.json and prints it.
#>
param(
  [string]$BusRoot = 'C:\Users\teppe\.local\daimon\bus'
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$ProcessNames = @('rustdesk','tailscaled','tailscale-ipn','remoting_host','codex','claude')
$ServiceNames = @('RustDesk','Tailscale','chromoting')
$RustDeskPort = 21118
$DynabookEndpoint = @{ host = '100.110.32.108'; port = 21118 }
$GalaxyEndpoint = @{ host = '100.65.78.107'; port = 21118 }

$processes = [ordered]@{}
foreach ($name in $ProcessNames) {
  $processes[$name] = @(Get-Process -Name $name -ErrorAction SilentlyContinue).Count
}

$services = [ordered]@{}
foreach ($name in $ServiceNames) {
  $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
  $services[$name] = if ($svc) { [ordered]@{ status = [string]$svc.Status; start_type = [string]$svc.StartType } } else { 'NOT_INSTALLED' }
}

$listening = $false
try {
  $listening = @(Get-NetTCPConnection -LocalPort $RustDeskPort -State Listen -ErrorAction SilentlyContinue).Count -gt 0
} catch {}

function Test-FixedEndpoint($Endpoint) {
  $probe = [ordered]@{ endpoint = "$($Endpoint.host):$($Endpoint.port)"; reachable = $false; connect_ms = $null }
  $client = [Net.Sockets.TcpClient]::new()
  try {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $task = $client.ConnectAsync($Endpoint.host, $Endpoint.port)
    if ($task.Wait(3000) -and $client.Connected) {
      $probe.reachable = $true
      $probe.connect_ms = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
    }
  } catch {
  } finally {
    $client.Dispose()
  }
  $probe
}
$probe = Test-FixedEndpoint $DynabookEndpoint
$galaxyProbe = Test-FixedEndpoint $GalaxyEndpoint

$report = [ordered]@{
  schema_version          = '1.0'
  tool                    = 'REMOTE_STATUS'
  generated_at            = [DateTimeOffset]::Now.ToString('o')
  hostname                = $env:COMPUTERNAME
  processes               = $processes
  services                = $services
  local_rustdesk_listen   = $listening
  dynabook_rustdesk_probe = $probe
  galaxy_rustdesk_probe   = $galaxyProbe
  secret_recorded         = $false
}

$resultDir = Join-Path $BusRoot 'results'
New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$path = Join-Path $resultDir "REMOTE_STATUS-$stamp.json"
$json = $report | ConvertTo-Json -Depth 6
$json | Set-Content -LiteralPath $path -Encoding utf8
$json | Write-Output
exit 0
