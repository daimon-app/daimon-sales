$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$manifest = Get-Content (Join-Path $root 'android\app\src\main\AndroidManifest.xml') -Raw
$gradle = Get-Content (Join-Path $root 'android\app\build.gradle') -Raw
$pack = Get-Content (Join-Path $root 'sales-ready\ANDROID_PLAY_RELEASE_PACK_2026-08-20.md') -Raw
$safety = Get-Content (Join-Path $root 'sales-ready\DATA_SAFETY_DRAFT_2026-08-20.md') -Raw
$device = Get-Content (Join-Path $root 'android\qa\OWNER_DEVICE_BATCH_2026-08-20.md') -Raw

$checks = @(
    @{ Name = 'No INTERNET permission'; Pass = $manifest -notmatch 'android.permission.INTERNET' },
    @{ Name = 'Backup disabled'; Pass = $manifest -match 'android:allowBackup="false"' },
    @{ Name = 'Cleartext disabled'; Pass = $manifest -match 'android:usesCleartextTraffic="false"' },
    @{ Name = 'Expected applicationId'; Pass = $gradle -match "applicationId 'app\.daimon'" },
    @{ Name = 'Expected candidate version'; Pass = $gradle -match "versionName '1\.0\.0-beta\.1'" },
    @{ Name = 'Privacy URL is not fabricated'; Pass = $pack -match 'Privacy URL \| `OWNER_INPUT_REQUIRED`' },
    @{ Name = 'Support URL is not fabricated'; Pass = $pack -match 'Support URL \| `OWNER_INPUT_REQUIRED`' },
    @{ Name = 'Device QA remains unverified'; Pass = ([regex]::Matches($device, 'UNVERIFIED')).Count -ge 12 },
    @{ Name = 'Data safety has revalidation triggers'; Pass = $safety -match 'Revalidation triggers' },
    @{ Name = 'No fake device PASS in device batch'; Pass = $device -notmatch '\| PASS \|' }
)

$failed = @($checks | Where-Object { -not $_.Pass })
$checks | ForEach-Object { '{0}: {1}' -f $(if ($_.Pass) { 'PASS' } else { 'FAIL' }), $_.Name }
if ($failed.Count -gt 0) { throw "Play release pack checks failed: $($failed.Count)" }
"SUMMARY: $($checks.Count) PASS / 0 FAIL"
