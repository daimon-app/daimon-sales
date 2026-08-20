<#
.SYNOPSIS
  Static readiness check for the DAIMON Android offline WebView shell.

.DESCRIPTION
  Verifies, without invoking Gradle/AGP or any network access, that:
   - the four-mode PWA source (index.html/manifest.json/sw.js/assets/icons)
     the Android project copies at build time is present at the repo root
   - the Android project files are well-formed XML
   - the security posture requested for this shell (no INTERNET permission,
     no cleartext traffic, exported launcher activity, minimal WebView file
     access) is actually present in the manifest / Gradle / Java source
   - the Gradle version/AGP/JDK/SDK pins match what was requested
  This is a static source check, not a build. It does not require the
  Android SDK, Gradle, or a JDK to be installed, and it makes no network
  calls. Exit code is non-zero if any hard check fails.

.NOTES
  Run from anywhere; paths are resolved relative to this script's location.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$AndroidRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $AndroidRoot

$script:FailCount = 0
$script:WarnCount = 0
$script:PassCount = 0

function Pass($msg) {
    Write-Host "  [PASS] $msg" -ForegroundColor Green
    $script:PassCount++
}
function Fail($msg) {
    Write-Host "  [FAIL] $msg" -ForegroundColor Red
    $script:FailCount++
}
function WarnCheck($msg) {
    Write-Host "  [WARN] $msg" -ForegroundColor Yellow
    $script:WarnCount++
}
function Section($title) {
    Write-Host ""
    Write-Host "== $title ==" -ForegroundColor Cyan
}

function Test-XmlWellFormed($path) {
    if (-not (Test-Path $path)) { return $false }
    try {
        [xml](Get-Content -Raw -Path $path) | Out-Null
        return $true
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
Section "PWA source present at repo root (bundled offline by copyPwaAssets)"
# ---------------------------------------------------------------------------

$RequiredPwaEntries = @('index.html', 'manifest.json', 'sw.js', 'assets', 'icons')
foreach ($entry in $RequiredPwaEntries) {
    $p = Join-Path $RepoRoot $entry
    if (Test-Path $p) {
        Pass "repo root has '$entry'"
    } else {
        Fail "repo root is missing required PWA entry '$entry' (needed by android/app/build.gradle copyPwaAssets)"
    }
}

$AssetsWork = Join-Path $RepoRoot 'assets/work'
$AssetsNight = Join-Path $RepoRoot 'assets/night'
foreach ($pair in @(@{Dir=$AssetsWork; Name='work'}, @{Dir=$AssetsNight; Name='night'})) {
    if (Test-Path $pair.Dir) {
        $count = (Get-ChildItem -Path $pair.Dir -Filter '*.jpg' -File -ErrorAction SilentlyContinue).Count
        if ($count -eq 12) {
            Pass "assets/$($pair.Name) has all 12 mode images"
        } else {
            WarnCheck "assets/$($pair.Name) has $count/12 expected images"
        }
    }
}

# ---------------------------------------------------------------------------
Section "Known pre-existing PWA issue: launcher icon source files"
# ---------------------------------------------------------------------------

$PngSignature = [byte[]](0x89, 0x50, 0x4E, 0x47)
foreach ($iconName in @('icon-192.png', 'icon-512.png')) {
    $iconPath = Join-Path $RepoRoot "icons/$iconName"
    if (Test-Path $iconPath) {
        $bytes = [System.IO.File]::ReadAllBytes($iconPath)
        $head = $bytes[0..3]
        $isPng = ($head.Length -eq 4) -and (Compare-Object $head $PngSignature -SyncWindow 0).Count -eq 0
        if ($isPng) {
            Pass "icons/$iconName is a valid PNG"
        } else {
            WarnCheck "icons/$iconName is NOT a valid PNG (bad signature) -- pre-existing PWA defect, not modified by this Android task; Android launcher icon uses a generated vector placeholder instead (see README 'Known issues')"
        }
    }
}

# ---------------------------------------------------------------------------
Section "Android project structure"
# ---------------------------------------------------------------------------

$RequiredFiles = @(
    'settings.gradle',
    'build.gradle',
    'gradle.properties',
    'gradle/wrapper/gradle-wrapper.properties',
    'app/build.gradle',
    'app/proguard-rules.pro',
    'app/src/main/AndroidManifest.xml',
    'app/src/main/java/app/daimon/MainActivity.java',
    'app/src/main/res/values/strings.xml',
    'app/src/main/res/values/styles.xml',
    'app/src/main/res/values/colors.xml',
    'app/src/main/res/xml/network_security_config.xml',
    'app/src/main/res/xml/data_extraction_rules.xml',
    'app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    'app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
    'app/src/main/res/mipmap/ic_launcher.xml',
    'app/src/main/res/mipmap/ic_launcher_round.xml',
    'app/src/main/res/drawable/ic_launcher_background.xml',
    'app/src/main/res/drawable/ic_launcher_foreground.xml'
)
foreach ($rel in $RequiredFiles) {
    $p = Join-Path $AndroidRoot $rel
    if (Test-Path $p) {
        Pass "android/$rel exists"
    } else {
        Fail "android/$rel is missing"
    }
}

$WrapperExecutables = @('gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar')
foreach ($rel in $WrapperExecutables) {
    $p = Join-Path $AndroidRoot $rel
    if (Test-Path $p) {
        Pass "android/$rel exists"
    } else {
        WarnCheck "android/$rel is not generated yet -- UNVERIFIED. Run 'gradle wrapper --gradle-version 8.9' from android/ on a machine with Gradle + network to generate it (not done here: no network / no Gradle binary available in this session, and gradle-wrapper.properties is a permission-gated file this session could not write)."
    }
}

# ---------------------------------------------------------------------------
Section "XML well-formedness"
# ---------------------------------------------------------------------------

$XmlFiles = Get-ChildItem -Path (Join-Path $AndroidRoot 'app/src/main') -Recurse -Filter '*.xml' -File -ErrorAction SilentlyContinue
foreach ($f in $XmlFiles) {
    $rel = $f.FullName.Substring($AndroidRoot.Length + 1)
    if (Test-XmlWellFormed $f.FullName) {
        Pass "android/$rel is well-formed XML"
    } else {
        Fail "android/$rel is NOT well-formed XML"
    }
}

# ---------------------------------------------------------------------------
Section "Manifest security posture"
# ---------------------------------------------------------------------------

$ManifestPath = Join-Path $AndroidRoot 'app/src/main/AndroidManifest.xml'
if (Test-Path $ManifestPath) {
    $manifestText = Get-Content -Raw -Path $ManifestPath

    if ($manifestText -notmatch 'uses-permission[^>]*INTERNET') {
        Pass "AndroidManifest.xml declares no INTERNET permission"
    } else {
        Fail "AndroidManifest.xml declares android.permission.INTERNET (must not, per requirements)"
    }

    if ($manifestText -match 'android:usesCleartextTraffic\s*=\s*"false"') {
        Pass "AndroidManifest.xml sets usesCleartextTraffic=false"
    } else {
        Fail "AndroidManifest.xml does not set usesCleartextTraffic=false"
    }

    if ($manifestText -match 'android:allowBackup\s*=\s*"false"') {
        Pass "AndroidManifest.xml sets allowBackup=false"
    } else {
        Fail "AndroidManifest.xml does not set allowBackup=false"
    }

    if ($manifestText -match 'android:screenOrientation\s*=\s*"portrait"') {
        Pass "launcher activity is locked to portrait"
    } else {
        Fail "launcher activity does not declare screenOrientation=portrait"
    }

    if ($manifestText -match 'android:exported\s*=\s*"true"') {
        Pass "launcher activity declares android:exported=true (required for targetSdk 31+)"
    } else {
        Fail "launcher activity does not declare android:exported"
    }

    if ($manifestText -match 'android:networkSecurityConfig\s*=\s*"@xml/network_security_config"') {
        Pass "application references network_security_config"
    } else {
        Fail "application does not reference a network security config"
    }
} else {
    Fail "AndroidManifest.xml not found"
}

$NscPath = Join-Path $AndroidRoot 'app/src/main/res/xml/network_security_config.xml'
if (Test-Path $NscPath) {
    $nscText = Get-Content -Raw -Path $NscPath
    if ($nscText -match 'cleartextTrafficPermitted\s*=\s*"false"') {
        Pass "network_security_config.xml sets cleartextTrafficPermitted=false"
    } else {
        Fail "network_security_config.xml does not set cleartextTrafficPermitted=false"
    }
}

# ---------------------------------------------------------------------------
Section "MainActivity WebView hardening"
# ---------------------------------------------------------------------------

$MainActivityPath = Join-Path $AndroidRoot 'app/src/main/java/app/daimon/MainActivity.java'
if (Test-Path $MainActivityPath) {
    $javaText = Get-Content -Raw -Path $MainActivityPath

    $webviewChecks = @(
        @{ Pattern = 'setJavaScriptEnabled\(true\)'; Desc = 'JavaScript enabled' },
        @{ Pattern = 'setDomStorageEnabled\(true\)'; Desc = 'DOM storage enabled' },
        @{ Pattern = 'setAllowFileAccess\(false\)'; Desc = 'generic filesystem file access disabled (android_asset stays reachable)' },
        @{ Pattern = 'setAllowFileAccessFromFileURLs\(false\)'; Desc = 'cross-file:// access disabled' },
        @{ Pattern = 'setAllowUniversalAccessFromFileURLs\(false\)'; Desc = 'universal file:// access disabled' },
        @{ Pattern = 'MIXED_CONTENT_NEVER_ALLOW'; Desc = 'mixed content blocked' },
        @{ Pattern = 'shouldOverrideUrlLoading'; Desc = 'external navigation gate present' },
        @{ Pattern = 'file:///android_asset/'; Desc = 'loads from bundled asset origin' }
        @{ Pattern = 'protected void onPause\(\)'; Desc = 'foreground loss lifecycle override present' }
        @{ Pattern = 'AudioHook\.stop\(\)'; Desc = 'background transition stops app audio' }
        @{ Pattern = 'webView\.pauseTimers\(\)'; Desc = 'background transition pauses JavaScript timers' }
        @{ Pattern = 'removeView\(webView\)'; Desc = 'WebView detached before destroy' }
        @{ Pattern = "showLayer\('scrHome'\)"; Desc = 'Android Back returns active mode to Home' }
    )
    foreach ($check in $webviewChecks) {
        if ($javaText -match $check.Pattern) {
            Pass "MainActivity.java: $($check.Desc)"
        } else {
            Fail "MainActivity.java: missing '$($check.Desc)' ($($check.Pattern))"
        }
    }

    if ($javaText -match 'onShowFileChooser') {
        WarnCheck "MainActivity.java overrides onShowFileChooser -- confirm it still returns false/disabled if this changes"
    } else {
        Pass "MainActivity.java: file chooser left unimplemented (disabled by default, no upload UI in the PWA)"
    }
} else {
    Fail "MainActivity.java not found"
}

# ---------------------------------------------------------------------------
Section "Version / SDK / toolchain pins"
# ---------------------------------------------------------------------------

$AppGradlePath = Join-Path $AndroidRoot 'app/build.gradle'
if (Test-Path $AppGradlePath) {
    $gradleText = Get-Content -Raw -Path $AppGradlePath

    $pinChecks = @(
        @{ Pattern = "namespace\s+'app\.daimon'"; Desc = "namespace = app.daimon" },
        @{ Pattern = "applicationId\s+'app\.daimon'"; Desc = "applicationId = app.daimon" },
        @{ Pattern = 'minSdk\s+23'; Desc = 'minSdk = 23' },
        @{ Pattern = 'targetSdk\s+35'; Desc = 'targetSdk = 35' },
        @{ Pattern = 'compileSdk\s+35'; Desc = 'compileSdk = 35' },
        @{ Pattern = 'versionCode\s+1'; Desc = 'versionCode = 1' },
        @{ Pattern = "versionName\s+'1\.0\.0-beta\.1'"; Desc = "versionName = 1.0.0-beta.1" },
        @{ Pattern = 'VERSION_17'; Desc = 'Java compatibility = 17' }
    )
    foreach ($check in $pinChecks) {
        if ($gradleText -match $check.Pattern) {
            Pass "app/build.gradle: $($check.Desc)"
        } else {
            Fail "app/build.gradle: expected '$($check.Desc)' not found"
        }
    }
} else {
    Fail "app/build.gradle not found"
}

$RootGradlePath = Join-Path $AndroidRoot 'build.gradle'
if (Test-Path $RootGradlePath) {
    $rootGradleText = Get-Content -Raw -Path $RootGradlePath
    if ($rootGradleText -match "com\.android\.application'\s+version\s+'8\.7") {
        Pass "root build.gradle pins AGP 8.7.x"
    } else {
        Fail "root build.gradle does not pin AGP 8.7.x"
    }
}

$WrapperPropsPath = Join-Path $AndroidRoot 'gradle/wrapper/gradle-wrapper.properties'
if (Test-Path $WrapperPropsPath) {
    $wrapperText = Get-Content -Raw -Path $WrapperPropsPath
    if ($wrapperText -match 'gradle-8\.9-bin\.zip') {
        Pass "gradle-wrapper.properties pins Gradle 8.9"
    } else {
        Fail "gradle-wrapper.properties does not pin Gradle 8.9"
    }
} else {
    WarnCheck "gradle/wrapper/gradle-wrapper.properties not present -- UNVERIFIED, see README 'Known issues'"
}

# ---------------------------------------------------------------------------
Section "Summary"
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Pass: $script:PassCount  Warn: $script:WarnCount  Fail: $script:FailCount"

if ($script:FailCount -gt 0) {
    Write-Host "READINESS: FAIL" -ForegroundColor Red
    exit 1
} else {
    Write-Host "READINESS: PASS (static checks only -- see WARN items and README 'Known issues' for what remains UNVERIFIED)" -ForegroundColor Green
    exit 0
}
