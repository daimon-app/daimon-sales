function Protect-AI5EvidenceValue {
    param($Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) {
        if (Get-Command Protect-AI5Text -ErrorAction SilentlyContinue) { return Protect-AI5Text $Value }
        return $Value -replace '(?i)(api[_-]?key|token|password|secret)\s*[:=]\s*([^\s,;]+)', '$1=[REDACTED]'
    }
    if ($Value -is [Collections.IDictionary]) {
        $copy = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $copy[$key] = if ([string]$key -match '(?i)(api[_-]?key|token|password|secret|authorization|cookie)$') { '[REDACTED]' } else { Protect-AI5EvidenceValue $Value[$key] }
        }
        return $copy
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        return @($Value | ForEach-Object { Protect-AI5EvidenceValue $_ })
    }
    if ($Value -is [psobject] -and $Value.PSObject.Properties.Count -gt 0) {
        $copy = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $copy[$property.Name] = if ($property.Name -match '(?i)(api[_-]?key|token|password|secret|authorization|cookie)$') { '[REDACTED]' } else { Protect-AI5EvidenceValue $property.Value }
        }
        return $copy
    }
    return $Value
}

function Export-AI5TaskEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$AppRoot,
        [Parameter(Mandatory = $true)]$Task,
        $Result,
        $Audit
    )

    $taskId = [string]$(if ($Task.task_id) { $Task.task_id } elseif ($Task.taskId) { $Task.taskId } else { '' })
    if ([string]::IsNullOrWhiteSpace($taskId)) { throw 'task_id_required' }
    $safeId = $taskId -replace '[^A-Za-z0-9_.-]', '_'
    $root = Join-Path $AppRoot 'evidence\tasks'
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $path = Join-Path $root ($safeId + '.json')
    $temp = Join-Path $root ('.' + $safeId + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')

    $record = [ordered]@{
        schema_version = 1
        task_id = $taskId
        exported_at = [DateTime]::UtcNow.ToString('o')
        task = Protect-AI5EvidenceValue $Task
        result = Protect-AI5EvidenceValue $Result
        audit = Protect-AI5EvidenceValue $Audit
    }
    try {
        $record | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $temp -Encoding UTF8
        Move-Item -LiteralPath $temp -Destination $path -Force
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    }

    [ordered]@{
        task_id = $taskId
        path = $path
        sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        committed = $false
        pushed = $false
    }
}
