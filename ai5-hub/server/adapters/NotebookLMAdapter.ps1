function Get-AI5NotebookLMHealth {
    $health = Get-AI5SpecialistHealth 'notebooklm'
    [ordered]@{ available=$health.available; connection=$health.connection; quota=$health.quota; mode='read_only'; requiresGithubVerification=$true }
}

function New-AI5NotebookLMRequest {
    param([string]$TaskId,[string]$Query,[string]$NotebookId)
    if ([string]::IsNullOrWhiteSpace($TaskId) -or [string]::IsNullOrWhiteSpace($Query)) { throw 'task_id_and_query_required' }
    [ordered]@{ taskId=$TaskId; query=$Query; notebookId=$NotebookId; mode='read_only'; requireSources=$true; createdAt=[DateTime]::UtcNow.ToString('o') }
}

function Test-AI5NotebookLMResult {
    param($Result)
    if (!$Result -or $Result.status -notin @('completed','blocked','failed')) { return $false }
    if ($Result.status -eq 'completed' -and @($Result.sources).Count -eq 0) { return $false }
    return [bool]$Result.requiresGithubVerification
}
