<#
DAIMON Tool Executor: DAIMON_REMOTE_GALAXY
Purpose                 : let DAIMON Remote (Galaxy app app.daimon.remote, RustDesk-based backend) be driven by
                          DAIMON over the existing USB ADB route, so the Owner never operates RustDesk directly.
Actions (fixed)         : ui         - foreground package; visible texts ONLY when the foreground is DAIMON Remote
                                       or the Android system consent UI (never other apps' screens).
                          host-start - make the Galaxy DAIMON Remote host listen on its tailnet port 21118:
                                       open DAIMON Remote, press DAIMON Remote's OWN start-service control
                                       (located by text, never by blind coordinates), then STOP at the Android
                                       screen-capture consent and report the one Owner tap it needs.
                                       Never taps a systemui / consent / password / lock screen element.
                          connect    - open a DAIMON Remote session from Galaxy to a registry device chosen by
                                       key (fujitsu|dynabook); endpoint comes from the registry, never from input.
                          disconnect - close the DAIMON Remote session view on Galaxy (back + DAIMON's own
                                       disconnect confirmation only).
                          host-wait  - touch nothing; poll up to 15 minutes for the Owner's consent taps and
                                       report which stage the Galaxy is at (DAIMON consent / Android consent /
                                       listening). Run in the background after host-start reaches a gate.
                          host-watch - touch nothing; sample every 30 s for -WatchMinutes and record each change of
                                       listen / screen capture / screen / fold / foreground package / power / USB,
                                       to find what ends the host (no screen contents are read).
Input schema            : -Action (ValidateSet), -Device (ValidateSet), -WaitSeconds (0..120), -WatchMinutes (1..110).
Path/scope restriction  : adb.exe at the fixed SDK path, exactly one authorized device; temp UI dump at
                          /data/local/tmp/daimon-remote-ui.xml (deleted after each read); report JSON in
                          <bus_root>\results\DAIMON_REMOTE_GALAXY-<action>-<timestamp>.json.
Never                   : reads or types passwords, grants permissions, changes appops/settings, unlocks the
                          screen, installs/uninstalls, force-stops apps, or touches stock RustDesk.
Exit codes              : 0 = report written (gates and failures are reported as data in "state").
#>
param(
  [Parameter(Mandatory = $true)][ValidateSet('ui', 'host-start', 'host-wait', 'host-watch', 'connect', 'disconnect')][string]$Action,
  [ValidateSet('fujitsu', 'dynabook')][string]$Device,
  [ValidateRange(0, 120)][int]$WaitSeconds = 20,
  [ValidateRange(1, 110)][int]$WatchMinutes = 100,
  # Failover drill: treat the private direct path as down without touching Tailscale/RustDesk/network settings.
  [switch]$SimulateDirectDown,
  [string]$BusRoot = 'C:\Users\teppe\.local\daimon\bus',
  [string]$RegistryPath = 'C:\Users\teppe\Documents\GitHub\daimon-sales\ai5-github-result-bus\config\daimon-remote-device-registry.json',
  [string]$Adb = (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)  # adb shell output is UTF-8
$Pkg = 'app.daimon.remote'
$Main = 'app.daimon.remote/com.carriez.flutter_hbb.MainActivity'
$TextVisiblePackages = @($Pkg, 'com.android.systemui')
# Labels inside DAIMON Remote (RustDesk-based UI, en + ja). \u escapes keep this file ASCII for PowerShell 5.1.
$ReStartService = '(?i)^(start service|\u30b5\u30fc\u30d3\u30b9\u3092\u958b\u59cb|\u30b5\u30fc\u30d3\u30b9\u958b\u59cb)$'
$ReShareTab     = '(?i)^(share screen|\u753b\u9762\u5171\u6709|\u753b\u9762\u3092\u5171\u6709)$'
$ReDisconnectOk = '(?i)^(ok|yes|disconnect|\u306f\u3044|\u5207\u65ad)$'
$ReConnectTab   = '(?i)^(connect|\' + 'u63a5\' + 'u7d9a)$'
$ReDisconnectQ  = '(?i)(close the connection|\' + 'u7d42\' + 'u4e86|disconnect|\u5207\u65ad)'
$RePassword     = '(?i)(password|\u30d1\u30b9\u30ef\u30fc\u30c9)'
# DAIMON Remote's anti-scam warning before host start. AI may only DECLINE/CLOSE it (safe side); accepting is
# the Owner's own consent and is never tapped by this tool.
$ReScamWarning  = '(?i)(scam|\u8a50\u6b3a)'
$ReWarnClose    = '(?i)^(close|\u9589\u3058\u308b)$'
$ReWarnDecline  = '(?i)^(decline|\u540c\u610f\u3057\u306a\u3044)$'
function Close-ScamWarning($nodes) {
  if (-not ($nodes | Where-Object { $_.package -eq $Pkg -and $_.label -match $ReScamWarning })) { return $false }
  $t = Tap-Own $nodes $ReWarnDecline
  if (-not $t) { $t = Tap-Own $nodes $ReWarnClose }
  return [bool]$t
}

function Sh([string]$c) { (@(& $Adb -s $script:Serial shell $c 2>$null) -join "`n").Trim() }
function Get-Foreground {
  $a = Sh 'dumpsys activity activities | grep -m1 topResumedActivity'
  if ($a -match '\{\S+ \S+ ([\w.]+)/([\w.$]+)') { return [pscustomobject]@{ package = $Matches[1]; activity = $Matches[2] } }
  return [pscustomobject]@{ package = ''; activity = '' }
}
function Get-Screen {
  # Single quotes inside: PowerShell 5.1 mangles embedded double quotes when passing args to adb.
  $w = Sh "dumpsys window | grep -E 'mDreamingLockscreen|isKeyguardShowing|mShowingLockscreen'"
  $script:LockLines = $w
  $p = Sh 'dumpsys power | grep -m1 mWakefulness='
  $ds = Sh 'cmd device_state print-state 2>/dev/null'
  $disp = Sh "dumpsys display | grep -E 'mScreenState=|mGlobalDisplayState=' | head -n 4"
  [pscustomobject]@{ awake = ($p -match 'mWakefulness=Awake'); locked = ($w -match '(mDreamingLockscreen|isKeyguardShowing|mShowingLockscreen)=true')
    device_state = $ds; display = ($disp -replace '\s+', ' '); has_focus = (Test-AnyFocus) }
}
function Test-AnyFocus {
  # Foldables keep one focus per display; the first one listed can be the switched-off cover display.
  return ((Sh "dumpsys window displays | grep mCurrentFocus=") -match 'mCurrentFocus=Window\{')
}
function Get-Nodes {
  # Visible text nodes, only for allowed foreground packages.
  $fg = Get-Foreground
  if ($TextVisiblePackages -notcontains $fg.package) { return @() }
  $script:LastDump = Sh 'uiautomator dump --compressed /data/local/tmp/daimon-remote-ui.xml 2>&1 | tail -n 1'
  $xml = Sh 'cat /data/local/tmp/daimon-remote-ui.xml; rm -f /data/local/tmp/daimon-remote-ui.xml'
  $nodes = foreach ($m in [regex]::Matches($xml, '<node [^>]*?text="([^"]*)"[^>]*?package="([^"]*)"[^>]*?content-desc="([^"]*)"[^>]*?clickable="(true|false)"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')) {
    $label = if ($m.Groups[1].Value) { $m.Groups[1].Value } else { $m.Groups[3].Value }
    $label = [System.Net.WebUtility]::HtmlDecode($label).Trim()
    if (-not $label -or $TextVisiblePackages -notcontains $m.Groups[2].Value) { continue }
    [pscustomobject]@{ label = $label; package = $m.Groups[2].Value; clickable = ($m.Groups[4].Value -eq 'true')
      x = [int](([int]$m.Groups[5].Value + [int]$m.Groups[7].Value) / 2); y = [int](([int]$m.Groups[6].Value + [int]$m.Groups[8].Value) / 2) }
  }
  return @($nodes)
}
function Tap-Own($nodes, [string]$re) {
  # Taps only a DAIMON Remote node whose first label line matches $re as a whole.
  $n = @($nodes | Where-Object { $_.package -eq $Pkg -and (($_.label -split "`n")[0].Trim()) -match $re }) | Select-Object -First 1
  if (-not $n) { return $null }
  # Short press; plain taps were dropped by Flutter tabs. Pin to the display that holds focus
  # (foldables: injected touches can otherwise land on the switched-off cover display).
  $d = if ((Sh "dumpsys input | grep -A1 -m1 FocusedWindows: | tail -n 1") -match 'displayId=(\d+)') { $Matches[1] } else { '0' }
  Sh "input touchscreen -d $d swipe $($n.x) $($n.y) $($n.x) $($n.y) 120" | Out-Null
  # Where the dispatcher sent / dropped the injected touch (window names only).
  $script:LastTapDispatch = @((Sh "dumpsys input | grep -A6 -E 'RecentQueue:|DropReason|LastDropped' | cut -c1-220 | head -n 16") -split "`n" | ForEach-Object { $_.Trim() })
  $script:LastTapDisplay = $d
  Start-Sleep -Milliseconds 1500
  return $n.label
}
function Test-Listen {
  $t = Sh 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null'
  return ($t -match '(?m)^\s*\d+:\s+[0-9A-F]+:527E\s+[0-9A-F]+:0000\s+0A\s')
}
function Get-EstablishedPeers {
  # Remote IPv4 of ESTABLISHED sockets whose remote port is 21118 (IPv4 and IPv4-mapped IPv6 rows).
  $t = Sh 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null'
  @([regex]::Matches($t, '(?m)^\s*\d+:\s+[0-9A-F]+:[0-9A-F]{4}\s+(?:0000000000000000FFFF0000)?([0-9A-F]{8}):527E\s+01\s') | ForEach-Object {
    $h = $_.Groups[1].Value
    (3..0 | ForEach-Object { [Convert]::ToInt32($h.Substring($_ * 2, 2), 16) }) -join '.'
  } | Select-Object -Unique)
}
function Test-Projection { return ((Sh 'dumpsys media_projection') -match [regex]::Escape($Pkg)) }

$report = [ordered]@{ schema_version = '1.0'; tool = 'DAIMON_REMOTE_GALAXY'; action = $Action
  generated_at = [DateTimeOffset]::Now.ToString('o'); state = 'NO_DEVICE'; steps = @(); secret_recorded = $false }
$lines = @(& $Adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice\s*$' })
if (-not (Test-Path -LiteralPath $Adb)) { $report.state = 'ADB_MISSING' }
elseif ($lines.Count -gt 1) { $report.state = 'MULTIPLE_DEVICES_REFUSED' }
elseif ($lines.Count -eq 1) {
  $script:Serial = ($lines[0] -split '\s+')[0]
  $installed = (Sh "pm list packages $Pkg") -match "(?m)^package:$([regex]::Escape($Pkg))\s*$"
  $screen = Get-Screen
  $report.screen = $screen
  $report.listen_21118 = Test-Listen
  $report.projection_held = Test-Projection
  if (-not $installed) { $report.state = 'DAIMON_REMOTE_NOT_INSTALLED' }
  elseif ($Action -eq 'ui') {
    $fg = Get-Foreground
    $report.foreground = $fg
    $report.visible = @(Get-Nodes | ForEach-Object { "$($_.package)|$($_.label)|$(if ($_.clickable) {'btn'} else {'txt'})|$($_.x),$($_.y)" })
    $report.ui_dump_status = $script:LastDump
    # Window names only (no content): which windows are focused / drawn on top.
    $report.lock_probe = $script:LockLines
    $report.focus = Sh "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' | head -n 2"
    # Foldables: focus is tracked per display; window names / display ids only.
    $report.focus_per_display = @((Sh "dumpsys window displays | grep -E 'Display: mDisplayId=|mCurrentFocus=|mFocusedApp='") -split "`n" | ForEach-Object { $_.Trim() } | Select-Object -First 12)
    $report.input_focus = @((Sh "dumpsys input | grep -E 'FocusedWindows|FocusedApplications|displayId=[0-9]+.*(focus|name)' | head -n 8") -split "`n" | ForEach-Object { $_.Trim() })
    $report.display_ids = Sh "dumpsys display | grep -E 'mDisplayId=|mState=' | head -n 8"
    $report.overlay_windows = @((Sh "dumpsys window windows | grep -E '^ *Window #' | head -n 12") -split "`n" |
      ForEach-Object { if ($_ -match 'Window\{\w+ u\d+ ([^}]+)\}') { $Matches[1] } })
    # Unlabelled DAIMON Remote controls (icon buttons): class + bounds only.
    if ((Get-Foreground).package -eq $Pkg) {
      Sh 'uiautomator dump --compressed /data/local/tmp/daimon-remote-ui.xml >/dev/null 2>&1' | Out-Null
      $x = Sh 'cat /data/local/tmp/daimon-remote-ui.xml; rm -f /data/local/tmp/daimon-remote-ui.xml'
      $report.unlabelled_controls = @([regex]::Matches($x, '<node [^>]*?text=""[^>]*?class="([^"]*)"[^>]*?package="app\.daimon\.remote"[^>]*?content-desc=""[^>]*?clickable="true"[^>]*?bounds="(\[[^"]*)"') |
        ForEach-Object { "$($_.Groups[1].Value)|$($_.Groups[2].Value)" } | Select-Object -First 30)
      $report.screen_size = Sh 'wm size'
    }
    $report.established_21118_sockets = [int](Sh "cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -c ':527E 01 '")
    $report.established_peers = @(Get-EstablishedPeers)
    $report.state = 'OK'
  }
  elseif ($Action -eq 'host-watch') {
    # Read-only: state flags and package names only. Keeps going when the device leaves USB and comes back.
    $deadline = (Get-Date).AddMinutes($WatchMinutes); $events = @(); $prev = $null; $samples = 0
    while ((Get-Date) -lt $deadline) {
      $present = @(& $Adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match "^$([regex]::Escape($script:Serial))\s+device\s*$" }).Count -eq 1
      $s = if (-not $present) { [ordered]@{ usb_adb = $false } } else {
        $sc = Get-Screen
        $bat = Sh "dumpsys battery | grep -E '^ *(level|AC powered|USB powered):'"
        [ordered]@{ usb_adb = $true; listen = (Test-Listen); projection = (Test-Projection); awake = $sc.awake; locked = $sc.locked
          fold_state = $sc.device_state; foreground = (Get-Foreground).package
          daimon_process = [bool](Sh "pidof $Pkg"); powered = ($bat -match '(AC|USB) powered: true')
          battery = if ($bat -match 'level: (\d+)') { [int]$Matches[1] } else { $null }; peers = @(Get-EstablishedPeers).Count }
      }
      $samples++
      $key = ($s.GetEnumerator() | Where-Object { $_.Key -ne 'battery' } | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ';'
      if ($key -ne $prev) { $s.at = [DateTimeOffset]::Now.ToString('o'); $events += [pscustomobject]$s; $prev = $key }
      Start-Sleep -Seconds 30
    }
    $report.samples = $samples
    $report.events = $events
    $lost = @($events | Where-Object { $_.usb_adb -and -not ($_.listen -and $_.projection) }) | Select-Object -First 1
    $report.host_lost_at = if ($lost) { $lost.at } else { $null }
    $report.state = if ($lost) { 'HOST_LOST' } elseif (@($events | Where-Object { -not $_.usb_adb }).Count) { 'HOST_UNKNOWN_DEVICE_LEFT_USB' } else { 'HOST_HELD' }
  }
  elseif ($Action -ne 'ui' -and (-not $screen.awake -or $screen.locked)) {
    $report.state = 'OWNER_GATE_SCREEN_LOCKED'
    $report.owner_action_ja = [regex]::Unescape('Galaxy\' + 'u306e\' + 'u753b\' + 'u9762\' + 'u30ed\' + 'u30c3\' + 'u30af\' + 'u3092\' + 'u89e3\' + 'u9664')  # unlock the Galaxy screen
  }
  elseif ($Action -eq 'host-start') {
    if ($report.listen_21118 -and $report.projection_held) { $report.state = 'HOST_READY_ALREADY' }
    else {
      Sh "am start -n $Main" | Out-Null; $report.steps += 'open_daimon_remote'
      Start-Sleep -Seconds 3
      if (-not (Test-AnyFocus)) {
        # Nothing has input focus (gesture/transition in progress or Owner handling the phone): do not tap.
        $report.state = 'GALAXY_INPUT_NOT_FOCUSED'
      }
      for ($i = 0; $i -lt 3 -and $report.state -eq 'NO_DEVICE'; $i++) {
        $fg = Get-Foreground
        if ($fg.package -eq 'com.android.systemui' -or $fg.activity -match 'MediaProjection') {
          $report.state = 'OWNER_GATE_ANDROID_SCREEN_CAPTURE_CONSENT'
          $report.consent_ui = @(Get-Nodes | ForEach-Object { "$($_.label)|$(if ($_.clickable) {'btn'} else {'txt'})" })
          break
        }
        $nodes = Get-Nodes
        if ($nodes | Where-Object { $_.package -eq $Pkg -and $_.label -match $ReScamWarning }) {
          $report.state = 'OWNER_GATE_DAIMON_REMOTE_HOST_CONSENT'
          $report.consent_ui = @($nodes | ForEach-Object { "$($_.label)|$(if ($_.clickable) {'btn'} else {'txt'})" })
          break
        }
        $t = Tap-Own $nodes $ReStartService
        if ($t) { $report.steps += "tap_own:$t"; Start-Sleep -Seconds 2; continue }
        $t = Tap-Own $nodes $ReShareTab
        if ($t) {
          $report.steps += "tap_own:$t"
          if ($i -eq 1) {
            # Tab press delivered but the page did not change (stuck Flutter view, seen 2026-10-19 22:20 and 2026-10-20):
            # recreate only the activity (NEW_TASK|CLEAR_TASK); services and the app process are left running.
            Sh "am start -f 0x10008000 -n $Main" | Out-Null; $report.steps += 'recreate_daimon_remote_activity'
            Start-Sleep -Seconds 4
          }
          continue
        }
        $report.daimon_ui = @($nodes | ForEach-Object { "$($_.label)|$(if ($_.clickable) {'btn'} else {'txt'})" })
        break
      }
      # 21118 starts listening as soon as the service starts, before the Owner's consent (measured 2026-10-21 22:29);
      # the host is ready only when screen capture is also granted.
      if ($report.state -notlike 'OWNER_GATE_*') {
        $deadline = (Get-Date).AddSeconds($WaitSeconds)
        while ((Get-Date) -lt $deadline -and -not ((Test-Listen) -and (Test-Projection))) { Start-Sleep -Seconds 2 }
      }
      $report.listen_21118 = Test-Listen
      $report.projection_held = Test-Projection
      if ($report.listen_21118 -and $report.projection_held) { $report.state = 'HOST_READY' }
      elseif ($report.state -eq 'NO_DEVICE' -and $report.listen_21118) { $report.state = 'HOST_LISTEN_WITHOUT_SCREEN_CAPTURE' }
      elseif ($report.state -eq 'NO_DEVICE') { $report.state = 'HOST_START_CONTROL_NOT_FOUND' }
      if ($script:LastTapDispatch) { $report.tap_display = $script:LastTapDisplay; $report.tap_dispatch = $script:LastTapDispatch }
      if ($report.state -like 'OWNER_GATE_*' -or $report.state -in @('GALAXY_INPUT_NOT_FOCUSED', 'HOST_START_CONTROL_NOT_FOUND', 'HOST_LISTEN_WITHOUT_SCREEN_CAPTURE')) {
        $report.owner_gate_id = 'GALAXY_DAIMON_REMOTE_HOST_CONSENT'
      }
    }
  }
  elseif ($Action -eq 'host-wait') {
    # Read-only watch: no taps, no intents. Ends at listen + screen capture granted, or after 15 minutes.
    $deadline = (Get-Date).AddMinutes(15); $stages = @()
    while ((Get-Date) -lt $deadline) {
      if ((Test-Listen) -and (Test-Projection)) { break }
      $fg = Get-Foreground
      $stage = if ($fg.package -eq 'com.android.systemui' -or $fg.activity -match 'MediaProjection') { 'ANDROID_SCREEN_CAPTURE_CONSENT' }
        elseif ($fg.package -eq $Pkg) { 'DAIMON_REMOTE' } else { 'OTHER:' + $fg.package }
      if ($stages.Count -eq 0 -or $stages[-1] -ne $stage) { $stages += $stage }
      Start-Sleep -Seconds 3
    }
    $report.stages_seen = $stages
    $report.listen_21118 = Test-Listen
    $report.projection_held = Test-Projection
    $ready = $report.listen_21118 -and $report.projection_held
    $report.state = if ($ready) { 'HOST_READY' } else { 'HOST_WAIT_TIMEOUT' }
    if (-not $ready) { $report.owner_gate_id = 'GALAXY_DAIMON_REMOTE_HOST_CONSENT' }
  }
  elseif ($Action -eq 'connect') {
    if (-not $Device) { $report.state = 'DEVICE_REQUIRED' }
    else {
      $reg = [IO.File]::ReadAllText($RegistryPath, [Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
      $d = @($reg.devices | Where-Object { $_.device_key -eq $Device })
      if ($d.Count -ne 1 -or [string]$d[0].tailscale_ip -notmatch '^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d{1,3}\.\d{1,3}$' -or [int]$d[0].rustdesk_port -ne 21118) {
        $report.state = 'REGISTRY_ENTRY_INVALID'
      } else {
        $ep = "$($d[0].tailscale_ip):21118"
        $report.target = [ordered]@{ device_key = $Device; display_name = [string]$d[0].display_name }
        $probe = Sh "toybox nc -z -w 3 $($d[0].tailscale_ip) 21118 >/dev/null 2>&1 && echo OPEN || echo CLOSED"
        $report.path_from_galaxy = $probe
        if ($SimulateDirectDown) { $probe = 'CLOSED'; $report.simulated_direct_down = $true }
        if ($probe -ne 'OPEN') {
          # FAILOVER: registry fallback for PCs is Chrome Remote Desktop (EMERGENCY_FALLBACK). Open it; signing in
          # / PIN there stays with the Owner. Next connect with the direct path OPEN fails back automatically.
          $report.route = 'EMERGENCY_FALLBACK_CHROME_REMOTE_DESKTOP'
          if ([string]$d[0].fallback -ne 'chrome-remote-desktop') { $report.state = 'TARGET_OFFLINE_NO_FALLBACK' }
          else {
            Sh 'monkey -p com.google.chromeremotedesktop -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1' | Out-Null
            Start-Sleep -Seconds 4
            $fg = Get-Foreground
            $report.foreground = $fg
            $report.state = if ($fg.package -match '^(com\.google\.chromeremotedesktop|com\.android\.chrome)$') { 'FAILOVER_FALLBACK_OPENED' } else { 'FAILOVER_FALLBACK_NOT_CONFIRMED' }
          }
        }
        else {
          $report.route = 'TAILSCALE_PRIVATE_RUSTDESK_DIRECT'
          if ((Get-Foreground).package -eq $Pkg -and (Close-ScamWarning (Get-Nodes))) { $report.steps += 'closed_host_warning(declined)' }
          Sh "am start -a android.intent.action.VIEW -d daimonremote://connection/new/$ep $Pkg" | Out-Null
          $report.steps += 'open_session_via_daimon_remote'
          Start-Sleep -Seconds 4
          if ([int](Sh "cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -c ':527E 01 '") -eq 0 -and (Get-Foreground).package -eq $Pkg) {
            # Deep link did not open a session: use DAIMON Remote's own device list. Only the card whose first line
            # equals the REGISTRY endpoint is tapped (no free text, no Owner input).
            $nodes = Get-Nodes
            $t = Tap-Own $nodes $ReConnectTab
            if ($t) { $report.steps += "tap_own:$t"; $nodes = Get-Nodes }
            # A device card has two lines: "<registry endpoint>" then "<user>@<registry hostname>". The single-line
            # node with the same text is the ID input field and is never tapped.
            $host_ = [string]$d[0].hostname
            $card = @($nodes | Where-Object { $_.package -eq $Pkg -and $_.clickable -and
              ($_.label -split "`n").Count -eq 2 -and ($_.label -split "`n")[0].Trim() -eq $ep -and
              ($_.label -split "`n")[1].Trim() -match ('@' + [regex]::Escape($host_) + '$') }) | Select-Object -First 1
            if ($card) {
              Sh "input tap $($card.x) $($card.y)" | Out-Null
              $report.steps += "tap_own_device_card:$($card.label -replace "`n", ' / ')"
            } else { $report.steps += 'device_card_not_found' }
          }
          $deadline = (Get-Date).AddSeconds([Math]::Max($WaitSeconds, 8))
          do {
            Start-Sleep -Seconds 2
            $fg = Get-Foreground
            $nodes = Get-Nodes
            $estab = Sh "cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -c ':527E 01 '"
            if ($nodes | Where-Object { $_.label -match $RePassword }) { $report.state = 'OWNER_GATE_PASSWORD_ON_DEVICE'; break }
            if ($fg.package -eq $Pkg -and $fg.activity -match 'MainActivity' -and [int]$estab -gt 0 -and -not ($nodes | Where-Object { $_.label -match '(?i)connecting|\u63a5\u7d9a\u4e2d' })) {
              $report.state = 'SESSION_OPEN'; break
            }
          } while ((Get-Date) -lt $deadline)
          $report.foreground = $fg
          $report.established_21118_sockets = [int]$estab
          $report.established_peers = @(Get-EstablishedPeers)
          if ($report.state -eq 'SESSION_OPEN' -and $report.established_peers -notcontains [string]$d[0].tailscale_ip) { $report.state = 'SESSION_PEER_MISMATCH' }
          $report.daimon_ui = @($nodes | ForEach-Object { "$($_.label)|$(if ($_.clickable) {'btn'} else {'txt'})" } | Select-Object -First 30)
          if ($report.state -eq 'NO_DEVICE') { $report.state = 'SESSION_NOT_CONFIRMED' }
        }
      }
    }
  }
  elseif ($Action -eq 'disconnect') {
    $before = [int](Sh "cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -c ':527E 01 '")
    $fg = Get-Foreground
    if ($fg.package -ne $Pkg) { $report.state = 'NO_DAIMON_SESSION_IN_FOREGROUND' }
    else {
      # DAIMON Remote session bottom bar: its leftmost control is "close session" (RustDesk mobile remote_page
      # layout). It only opens DAIMON Remote's own confirmation; OK is tapped only if that question is shown.
      Sh 'uiautomator dump --compressed /data/local/tmp/daimon-remote-ui.xml >/dev/null 2>&1' | Out-Null
      $x = Sh 'cat /data/local/tmp/daimon-remote-ui.xml; rm -f /data/local/tmp/daimon-remote-ui.xml'
      $btns = @([regex]::Matches($x, '<node [^>]*?class="android\.widget\.Button"[^>]*?package="app\.daimon\.remote"[^>]*?content-desc=""[^>]*?clickable="true"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"') |
        ForEach-Object { [pscustomobject]@{ x1 = [int]$_.Groups[1].Value; y1 = [int]$_.Groups[2].Value; x2 = [int]$_.Groups[3].Value; y2 = [int]$_.Groups[4].Value } })
      $maxY = ($btns | Measure-Object -Property y2 -Maximum).Maximum
      $close = $btns | Where-Object { $_.y2 -eq $maxY -and $_.x1 -eq 0 } | Select-Object -First 1
      if ($close) {
        Sh "input tap $([int](($close.x1 + $close.x2) / 2)) $([int](($close.y1 + $close.y2) / 2))" | Out-Null
        Start-Sleep -Seconds 2; $report.steps += 'tap_own:session_close_control'
      }
      $nodes = Get-Nodes
      $report.confirm_ui = @($nodes | ForEach-Object { "$($_.label)|$(if ($_.clickable) {'btn'} else {'txt'})" })
      if ($nodes | Where-Object { $_.package -eq $Pkg -and $_.label -match $ReDisconnectQ }) {
        $t = Tap-Own $nodes $ReDisconnectOk
        if ($t) { $report.steps += "tap_own:$t" }
      }
      Start-Sleep -Seconds 3
      $after = [int](Sh "cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -c ':527E 01 '")
      $report.established_before = $before; $report.established_after = $after
      $report.daimon_ui = @(Get-Nodes | ForEach-Object { "$($_.label)|$(if ($_.clickable) {'btn'} else {'txt'})" } | Select-Object -First 30)
      $report.state = if ($after -lt $before -or ($before -eq 0 -and $after -eq 0)) { 'DISCONNECTED' } else { 'DISCONNECT_NOT_CONFIRMED' }
    }
  }
}
$dir = Join-Path $BusRoot 'results'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$json = $report | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText((Join-Path $dir ("DAIMON_REMOTE_GALAXY-{0}-{1}.json" -f $Action, (Get-Date -Format 'yyyyMMdd-HHmmss'))), $json, [Text.UTF8Encoding]::new($false))
$json
exit 0
