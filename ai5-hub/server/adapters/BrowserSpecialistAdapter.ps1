function New-AI5BrowserSpecialistRequest {
    param([string]$TaskId,[ValidateSet('gemini','manus')][string]$Agent,[string]$Objective,[string]$Mode='read_only')
    if ([string]::IsNullOrWhiteSpace($TaskId) -or [string]::IsNullOrWhiteSpace($Objective)) { throw 'task_id_and_objective_required' }
    if ($Mode -ne 'read_only') { throw 'browser_specialist_requires_approval_for_write' }
    [ordered]@{task_id=$TaskId;agent=$Agent;objective=$Objective;mode='read_only';require_sources=($Agent-eq'gemini');created_at=[DateTime]::UtcNow.ToString('o')}
}

function ConvertTo-AI5SpecialistResult {
    param($Request,[string]$Summary,[array]$Sources=@(),[array]$Risks=@())
    if ([string]::IsNullOrWhiteSpace($Summary)) { throw 'specialist_summary_required' }
    [ordered]@{task_id=$Request.task_id;agent=$Request.agent;status='SUCCESS';summary=$Summary;findings=@($Summary);changes=@();artifacts=@($Sources);tests=@("$($Request.agent) read-only browser result collected");risks=@($Risks);next_action='VALIDATE';needs_human=$false;human_reason=$null}
}

function Test-AI5SpecialistLiveEvidence {
    param([ValidateSet('gemini','manus')][string]$Agent,[string]$Summary,[array]$Tests=@())
    $marker = $Agent.ToUpperInvariant() + ' LIVE PASS'
    if ($Summary -notmatch ('(?im)^\s*' + [regex]::Escape($marker) + '\s*$')) { return $false }
    $joined = @($Tests) -join ' | '
    [bool]($joined -match ('(?i)' + [regex]::Escape($Agent) + '.*(?:live|exact|実応答).*PASS'))
}

function Merge-AI5AgentResults {
    param([array]$Results)
    $valid=@($Results|Where-Object{$_ -and $_.status -in @('SUCCESS','NEEDS_REVIEW')})
    [ordered]@{status=$(if($valid.Count-eq@($Results).Count){'SUCCESS'}elseif($valid.Count-gt0){'PARTIAL'}else{'FAILED'});summaries=@($valid|ForEach-Object{"$($_.agent): $($_.summary)"});findings=@($valid|ForEach-Object{@($_.findings)});risks=@($Results|ForEach-Object{@($_.risks)});agents=@($Results|ForEach-Object{$_.agent})}
}
