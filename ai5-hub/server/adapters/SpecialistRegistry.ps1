$script:AI5SpecialistAgentAllowlist = @('manus', 'gemini', 'notebooklm')
$script:AI5MeasurementReadyWindowMinutes = 30

function Initialize-AI5SpecialistRegistry {
    param([string]$ServerRoot)
    $script:AgentRegistryRoot = Join-Path $ServerRoot 'runtime\agents'
    New-Item -ItemType Directory -Force $script:AgentRegistryRoot | Out-Null
}

function Test-AI5SpecialistHealthSecretValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return [bool]($Value -match '(?i)(api[_-]?key|secret|passwd|password|bearer\s|authorization\s*:|(^|[^a-z])token\s*=|access[_-]?token|refresh[_-]?token|private[_-]?key|-----BEGIN)')
}

# READY is only trustworthy while the measurement that produced it is recent and passing;
# anything unconfirmed or stale must never be reported back as READY.
function Resolve-AI5SpecialistMeasuredState {
    param([string]$RequestedState, [string]$MeasurementResult, [DateTime]$CheckedAtUtc)
    if ($RequestedState -ne 'READY') { return $RequestedState }
    if ($MeasurementResult -ne 'PASS') { return 'DEGRADED' }
    $ageMinutes = ([DateTime]::UtcNow - $CheckedAtUtc).TotalMinutes
    if ($ageMinutes -gt $script:AI5MeasurementReadyWindowMinutes -or $ageMinutes -lt -5) { return 'OFFLINE' }
    return 'READY'
}

# Internal-only: writes a specialist health record from real measurement results.
# Not exposed over HTTP - callers are in-process adapters (eg. Register-AI5ManusMeasuredHealth).
function Set-AI5SpecialistHealthRecord {
    param(
        [string]$Agent,
        [string]$Connection,
        [string]$CheckedAt,
        [string]$Quota = 'unknown',
        [string]$PreferredRoute = '',
        [string]$AppState = 'OFFLINE',
        [string]$WebState = 'OFFLINE',
        [ValidateSet('PASS', 'FAIL', 'UNKNOWN')][string]$AppMeasurementResult = 'UNKNOWN',
        [ValidateSet('PASS', 'FAIL', 'UNKNOWN')][string]$WebMeasurementResult = 'UNKNOWN',
        [string]$AppAutomation = '',
        [string]$AppIdentity = '',
        [string]$AppVersion = '',
        [string]$Publisher = '',
        [string]$InstallSource = '',
        [bool]$AppAuthenticated = $false,
        [bool]$WebAuthenticated = $false
    )
    if ([string]::IsNullOrWhiteSpace($Agent) -or [string]::IsNullOrWhiteSpace($Connection) -or [string]::IsNullOrWhiteSpace($CheckedAt)) {
        throw 'specialist_health_agent_connection_checked_at_required'
    }
    if ($Agent -notin $script:AI5SpecialistAgentAllowlist) { throw 'specialist_agent_not_allowed' }
    foreach ($value in @($Connection, $Quota, $PreferredRoute, $AppAutomation, $AppIdentity, $AppVersion, $Publisher, $InstallSource)) {
        if (Test-AI5SpecialistHealthSecretValue $value) { throw 'specialist_health_secret_value_rejected' }
    }
    $checkedAtUtc = ConvertTo-AI5UtcDateTime $CheckedAt
    $resolvedAppState = Resolve-AI5SpecialistMeasuredState $AppState $AppMeasurementResult $checkedAtUtc
    $resolvedWebState = Resolve-AI5SpecialistMeasuredState $WebState $WebMeasurementResult $checkedAtUtc
    $record = [ordered]@{
        connection = $Connection
        checked_at = $checkedAtUtc.ToString('o')
        quota = $Quota
        preferred_route = $PreferredRoute
        app_state = $resolvedAppState
        web_state = $resolvedWebState
        app_automation = $AppAutomation
        app_identity = $AppIdentity
        app_version = $AppVersion
        publisher = $Publisher
        install_source = $InstallSource
        app_authenticated = [bool]$AppAuthenticated
        web_authenticated = [bool]$WebAuthenticated
    }
    $path = Join-Path $script:AgentRegistryRoot ($Agent + '.json')
    ($record | ConvertTo-Json -Depth 5) | Set-Content -Encoding UTF8 -LiteralPath $path
    $record
}

function Get-AI5SpecialistHealth {
    param([string]$Agent)
    $path = Join-Path $script:AgentRegistryRoot ($Agent + '.json')
    if (!(Test-Path $path)) {
        return [ordered]@{ available = $false; connection = 'not_connected'; quota = 'unknown' }
    }
    try {
        $record = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
        $fresh = ([DateTime]::UtcNow - (ConvertTo-AI5UtcDateTime $record.checked_at)).TotalHours -lt 24
        return [ordered]@{
            available = $fresh
            connection = $(if ($fresh) { $record.connection } else { 'stale' })
            quota = $record.quota
            checked_at = $record.checked_at
            preferredRoute = $record.preferred_route
            appState = $record.app_state
            appAutomation = $record.app_automation
            webState = $record.web_state
            appIdentity = $record.app_identity
            appVersion = $record.app_version
            publisher = $record.publisher
            installSource = $record.install_source
            appAuthenticated = [bool]$record.app_authenticated
            webAuthenticated = [bool]$record.web_authenticated
        }
    } catch {
        return [ordered]@{ available = $false; connection = 'error'; quota = 'unknown' }
    }
}
