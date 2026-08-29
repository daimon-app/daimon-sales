function Get-AI5ExecutionPlan {
    param($Route)
    $agents = @($Route.primary) + @($Route.secondary) | Select-Object -Unique
    $readOnly = @($agents | Where-Object { $_ -in @('claude','gemini','manus','notebooklm') })
    $stages = @([ordered]@{ order=1; mode='sequential'; agents=@('codex'); purpose='inspect_source_of_truth' })
    if ($readOnly.Count -gt 0) {
        $stages += ,[ordered]@{ order=2; mode=$(if($readOnly.Count-gt 1){'parallel'}else{'sequential'}); agents=$readOnly; purpose='specialist_read_only' }
    }
    $stages += ,[ordered]@{ order=3; mode='sequential'; agents=@('codex'); purpose='single_writer_execution' }
    $stages += ,[ordered]@{ order=4; mode='sequential'; agents=@('zero'); purpose='validation_and_completion' }
    [ordered]@{ mode=$Route.executionMode; single_writer='codex'; stages=$stages }
}

function Get-AI5FieldModeDecision {
    param($Route,[bool]$Enabled=$true)
    if (!$Enabled) { return [ordered]@{ action='STANDARD'; stop=$false; reason='field_mode_disabled' } }
    if ($Route.requiresApproval) { return [ordered]@{ action='WAIT_APPROVAL'; stop=$true; reason=$Route.approvalType } }
    [ordered]@{ action='AUTO_CONTINUE'; stop=$false; reason='safe_reversible_no_cost' }
}

function Get-AI5RecoveryDecision {
    param($Task,[string]$ErrorType,[string]$Fingerprint)
    $seen = @($Task.failure_fingerprints)
    $sameCount = @($seen | Where-Object { $_ -eq $Fingerprint }).Count
    if ([int]$Task.attempt -ge [int]$Task.max_attempts -or $sameCount -ge 2) {
        return [ordered]@{ action='FAILED'; retry=$false; reason=$(if($sameCount-ge 2){'repeated_failure'}else{'max_attempts'}) }
    }
    $action = Get-AI5FailureAction $Task $ErrorType
    [ordered]@{ action=$action; retry=($action -notin @('FAILED','WAIT_APPROVAL')); reason=$ErrorType }
}
