function Initialize-AI5SpecialistRegistry {
    param([string]$ServerRoot)
    $script:AgentRegistryRoot = Join-Path $ServerRoot 'runtime\agents'
    New-Item -ItemType Directory -Force $script:AgentRegistryRoot | Out-Null
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
            mailState = $record.mail_state
            mailSenderStatus = $record.mail_sender_status
            directState = $record.direct_state
            directVerified = [bool]$record.direct_verified
            currentTask = $record.current_task
            mailSent = [bool]$record.mail_sent
            manusActive = [bool]$record.manus_active
            resultReceived = [bool]$record.result_received
            resultVerified = [bool]$record.result_verified
            cost = $record.cost
            ownerGate = [bool]$record.owner_gate
        }
    } catch {
        return [ordered]@{ available = $false; connection = 'error'; quota = 'unknown' }
    }
}
