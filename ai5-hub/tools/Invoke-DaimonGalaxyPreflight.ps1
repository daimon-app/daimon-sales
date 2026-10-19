<#
DAIMON Tool Executor: GALAXY_PREFLIGHT
Exact allowed operation : read-only Galaxy hardware/OS/resource facts for GALAXY_LOCAL_AI sizing, via
                          the existing USB ADB route. Runs only the fixed read-only shell queries below
                          (getprop, /proc/meminfo, df, dumpsys battery/thermalservice/SurfaceFlinger,
                          vendor lib name match, package-name match against a FIXED runtime list,
                          FIXED remote-app list state (dumpsys package/activity services, pidof),
                          tun0 IPv4, and a LISTEN check for port 21118 in /proc/net/tcp*).
                          Never installs, changes settings, opens apps, reads user data, or connects
                          wireless ADB. The device serial is recorded only as a SHA-256 prefix.
Input schema            : none except -BusRoot (output directory).
Path/scope restriction  : adb.exe at the fixed Android SDK path; writes only
                          <bus_root>\results\GALAXY_PREFLIGHT-<timestamp>.json.
Timeout                 : each adb call is bounded by adb itself; no long-running commands.
Exit codes              : 0 = report written (NO_DEVICE / UNAUTHORIZED are reported as data).
Result/Receipt/Evidence : writes the JSON report and prints it.
Owner Gate auto-resume  : with -GateTaskId (must match ^GALAXY-[A-Z0-9-]+$), when the device is
                          AUTHORIZED and that Result Bus task is WAITING_OWNER_GATE with gate
                          GALAXY_DEVICE_CONNECT, writes an owner-gate observation (evidence = SHA-256
                          of this report) and hands it to Resume-AI5OwnerGateTask.ps1, which verifies
                          and fail-closes on any mismatch. No other bus file is touched.
#>
param(
  [string]$BusRoot = 'C:\Users\teppe\.local\daimon\bus',
  [ValidatePattern('^GALAXY-[A-Z0-9-]+$')][string]$GateTaskId,
  # The two parameters below exist only so the gate test can use a fake adb and a temp bus.
  [string]$ResultBusRepo = 'C:\Users\teppe\Documents\GitHub\daimon-sales\ai5-github-result-bus',
  [string]$Adb = (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
)
$ErrorActionPreference = 'Continue'  # adb writes daemon notices to stderr; failures are reported as data
$KnownRuntimePackages = @(
  'com.google.ai.edge.gallery', 'ai.mlc.mlcchat', 'com.pocketpalai', 'com.termux',
  'io.github.ggerganov.llamacpp', 'com.layla.ai', 'com.maid.app', 'com.chatterui.app'
)
# app.daimon.remote = DAIMON Remote (Owner entry; RustDesk-based backend). com.carriez.flutter_hbb = stock RustDesk.
$KnownRemotePackages = @('app.daimon.remote', 'com.carriez.flutter_hbb', 'com.tailscale.ipn', 'com.google.chromeremotedesktop')
# dynabook and FUJITSU RustDesk direct ports on the DAIMON tailnet
# (ai5-github-result-bus/config/daimon-remote-device-registry.json).
$PhoneProbeEndpoints = @('100.110.32.108:21118', '100.75.128.87:21118')

function Invoke-AdbShell([string]$Serial, [string]$Command) {
  $out = & $Adb -s $Serial shell $Command 2>$null
  return (@($out) -join "`n").Trim()
}

$report = [ordered]@{
  schema_version = '1.0'
  tool           = 'GALAXY_PREFLIGHT'
  generated_at   = [DateTimeOffset]::Now.ToString('o')
  host           = $env:COMPUTERNAME
  adb_present    = (Test-Path -LiteralPath $Adb)
  device_state   = 'NO_DEVICE'
  secret_recorded = $false
}

if ($report.adb_present) {
  $lines = @(& $Adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\S' })
  $devices = foreach ($l in $lines) { $p = $l -split '\s+'; [pscustomobject]@{ serial = $p[0]; state = $p[1] } }
  $devices = @($devices)
  $report.device_count = $devices.Count
  $ready = @($devices | Where-Object { $_.state -eq 'device' })
  if ($devices.Count -gt 0 -and $ready.Count -eq 0) { $report.device_state = ($devices | Select-Object -First 1).state.ToUpperInvariant() }
  if ($ready.Count -gt 1) { $report.device_state = 'MULTIPLE_DEVICES_REFUSED' }
  if ($ready.Count -eq 1) {
    $s = $ready[0].serial
    $sha = [Security.Cryptography.SHA256]::Create()
    $report.device_serial_sha256_prefix = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($s))) -replace '-', '').Substring(0, 12).ToLowerInvariant()
    $report.device_state = 'AUTHORIZED'
    $props = [ordered]@{}
    foreach ($k in 'ro.product.manufacturer','ro.product.model','ro.product.marketname','ro.soc.manufacturer','ro.soc.model',
                   'ro.board.platform','ro.hardware','ro.build.version.release','ro.build.version.sdk','ro.product.cpu.abilist',
                   'ro.hardware.vulkan','ro.hardware.egl') {
      $props[$k] = Invoke-AdbShell $s "getprop $k"
    }
    $report.props = $props
    $mem = Invoke-AdbShell $s 'cat /proc/meminfo'
    $kb = { param($name) if ($mem -match "(?m)^$name\:\s+(\d+)") { [math]::Round([double]$Matches[1] / 1MB, 2) } else { $null } }
    $report.memory_gib = [ordered]@{ total = (& $kb 'MemTotal'); available = (& $kb 'MemAvailable'); swap_total = (& $kb 'SwapTotal'); swap_free = (& $kb 'SwapFree') }
    $report.storage_data = Invoke-AdbShell $s 'df -h /data | tail -n 1'
    $battery = Invoke-AdbShell $s 'dumpsys battery'
    $report.battery = [ordered]@{
      level       = if ($battery -match '(?m)^\s*level:\s*(\d+)') { [int]$Matches[1] } else { $null }
      temperature_c = if ($battery -match '(?m)^\s*temperature:\s*(\d+)') { [int]$Matches[1] / 10 } else { $null }
      status      = if ($battery -match '(?m)^\s*status:\s*(\d+)') { [int]$Matches[1] } else { $null }
      ac_or_usb_powered = ($battery -match '(?m)^\s*(AC|USB) powered:\s*true')
    }
    $thermal = Invoke-AdbShell $s 'dumpsys thermalservice'
    $report.thermal = [ordered]@{
      thermal_status = if ($thermal -match 'Thermal Status:\s*(\d+)') { [int]$Matches[1] } else { $null }
      temperatures   = @([regex]::Matches($thermal, 'mValue=([\d.]+), mType=(\d+), mName=(\w+)') | Select-Object -First 12 |
                         ForEach-Object { "$($_.Groups[3].Value)=$($_.Groups[1].Value)C(type$($_.Groups[2].Value))" })
    }
    $report.gpu = Invoke-AdbShell $s 'dumpsys SurfaceFlinger | grep -m1 GLES'
    $report.accelerator_libs = @((Invoke-AdbShell $s 'ls /vendor/lib64 2>/dev/null') -split "`n" |
      Where-Object { $_ -match '(?i)qnn|htp|hexagon|eden|enn|npu|neuralnetworks|tflite|litert' } | Select-Object -First 20)
    $installed = Invoke-AdbShell $s 'pm list packages'
    $report.local_ai_runtimes_installed = @($KnownRuntimePackages | Where-Object { $installed -match "(?m)^package:$([regex]::Escape($_))\s*$" })
    # DAIMON Remote apps: FIXED package list, read-only (version, process, service records). Never starts them.
    $remote = [ordered]@{}
    foreach ($pkg in $KnownRemotePackages) {
      $entry = [ordered]@{ installed = ($installed -match "(?m)^package:$([regex]::Escape($pkg))\s*$") }
      if ($entry.installed) {
        $ver = Invoke-AdbShell $s "dumpsys package $pkg | grep -m1 versionName"
        $entry.version = ($ver -replace '^\s*versionName=', '')
        $entry.process_running = [bool](Invoke-AdbShell $s "pidof $pkg")
        $svc = Invoke-AdbShell $s "dumpsys activity services $pkg"
        $entry.service_records = ([regex]::Matches($svc, 'ServiceRecord\{')).Count
        $entry.foreground_service = ($svc -match 'isForeground=true')
        $entry.service_classes = @([regex]::Matches($svc, 'ServiceRecord\{\w+ u\d+ [\w.]+/([\w.$]+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
      }
      $remote[$pkg] = $entry
    }
    $report.remote_apps = $remote
    # DAIMON Remote component map (names and intent actions only) so the launcher can reach the host-start screen.
    if ($remote['app.daimon.remote'].installed) {
      $pkgDump = Invoke-AdbShell $s 'dumpsys package app.daimon.remote'
      $report.daimon_remote_components = [ordered]@{
        components = @([regex]::Matches($pkgDump, 'app\.daimon\.remote/([\w.$]+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        actions    = @([regex]::Matches($pkgDump, 'Action: "([\w.]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        schemes    = @([regex]::Matches($pkgDump, 'Scheme: "([\w.+-]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        granted_runtime = @([regex]::Matches($pkgDump, '(android\.permission\.[A-Z_]+): granted=true') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
      }
    }
    # tailnet IPv4 on tun0 (address only) and whether anything listens on RustDesk direct port 21118 (0x527E).
    $report.tun0_ipv4 = Invoke-AdbShell $s "ip -4 addr show tun0 2>/dev/null | grep -m1 -o 'inet [0-9.]*'"
    $tcp = Invoke-AdbShell $s 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null'
    $report.rustdesk_21118_listen = ($tcp -match '(?m)^\s*\d+:\s+[0-9A-F]+:527E\s+[0-9A-F]+:0000\s+0A\s')
    $report.proc_net_tcp_listen_entries = ([regex]::Matches($tcp, '(?m)^\s*\d+:\s+[0-9A-F]+:[0-9A-F]{4}\s+[0-9A-F]+:0000\s+0A\s')).Count
    # Path check FROM the phone to FIXED DAIMON Remote endpoints (TCP connect only, 3 s timeout, no payload).
    $report.phone_tcp_probes = [ordered]@{}
    foreach ($ep in $PhoneProbeEndpoints) {
      $r = Invoke-AdbShell $s "toybox nc -z -w 3 $($ep.Split(':')[0]) $($ep.Split(':')[1]) >/dev/null 2>&1 && echo OPEN || echo CLOSED"
      $report.phone_tcp_probes[$ep] = $r
    }
    # Screen-capture consent state (MediaProjection). Read-only; granting it is an Owner action on the phone.
    $mp = Invoke-AdbShell $s 'dumpsys media_projection'
    $report.media_projection = [ordered]@{
      rustdesk_holds_projection = ($mp -match 'com\.carriez\.flutter_hbb')
      any_projection_active     = ($mp -match '(?i)media projection(?: is|:)?\s*(?:active|running)|mProjectionGrant=\S*\{')
    }
  }
}

$resultDir = Join-Path $BusRoot 'results'
New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
$path = Join-Path $resultDir ("GALAXY_PREFLIGHT-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$json = $report | ConvertTo-Json -Depth 6
$json | Set-Content -LiteralPath $path -Encoding utf8
$json | Write-Output

if ($GateTaskId -and $report.device_state -eq 'AUTHORIZED') {
  $utf8 = [Text.UTF8Encoding]::new($false)
  $taskPath = Join-Path $ResultBusRepo "bus\tasks\$GateTaskId.json"
  if (Test-Path -LiteralPath $taskPath) {
    $task = [IO.File]::ReadAllText($taskPath, $utf8) | ConvertFrom-Json
    # Each gate has exactly one measured completion condition; anything else stays waiting (fail-closed).
    $gateMet = switch ([string]$task.owner_gate_id) {
      'GALAXY_DEVICE_CONNECT'         { $true }  # AUTHORIZED already checked above
      'GALAXY_DAIMON_REMOTE_HOST_CONSENT' { [bool]$report.rustdesk_21118_listen }
      default                         { $false }
    }
    $detectorName = if ([string]$task.owner_gate_id -eq 'GALAXY_DAIMON_REMOTE_HOST_CONSENT') { 'GALAXY_PREFLIGHT_DAIMON_REMOTE_21118_LISTEN' } else { 'GALAXY_PREFLIGHT_ADB_AUTHORIZED' }
    if ([string]$task.status -eq 'WAITING_OWNER_GATE' -and $gateMet) {
      $obsDir = Join-Path $ResultBusRepo 'bus\state\owner-gate-observations'
      New-Item -ItemType Directory -Force -Path $obsDir | Out-Null
      $obsPath = Join-Path $obsDir "$GateTaskId.json"
      $observation = [ordered]@{
        task_id = $GateTaskId
        gate_id = [string]$task.owner_gate_id
        decision_version = [string]$task.decision_version
        status = 'OWNER_GATE_COMPLETED'
        completion_verified = $true
        completion_evidence_sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        completion_evidence = (Split-Path -Leaf $path)
        detector = $detectorName
        observed_at = [DateTimeOffset]::Now.ToString('o')
        secret_recorded = $false
      }
      [IO.File]::WriteAllText($obsPath, ($observation | ConvertTo-Json -Depth 5), $utf8)
      $ErrorActionPreference = 'Stop'
      & (Join-Path $ResultBusRepo 'worker\Resume-AI5OwnerGateTask.ps1') -RepoRoot $ResultBusRepo -TaskPath $taskPath -ObservationPath $obsPath |
        ConvertTo-Json -Compress | Write-Output
    }
  }
}
exit 0
