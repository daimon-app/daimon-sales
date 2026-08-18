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
        }
    } catch {
        return [ordered]@{ available = $false; connection = 'error'; quota = 'unknown' }
    }
}
