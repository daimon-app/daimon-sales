function New-AI5ManusRequest {
    param(
        [Parameter(Mandatory=$true)][string]$TaskId,
        [Parameter(Mandatory=$true)][string]$Objective,
        [ValidateSet('read_only','execution')][string]$Mode='read_only',
        [string]$ProjectId='',
        [bool]$ApprovalRequired=$false
    )
    if ([string]::IsNullOrWhiteSpace($TaskId) -or [string]::IsNullOrWhiteSpace($Objective)) { throw 'task_id_and_objective_required' }
    if ($Mode -eq 'execution' -and !$ApprovalRequired) { throw 'manus_execution_requires_approval' }
    [ordered]@{taskId=$TaskId;objective=$Objective;mode=$Mode;projectId=$ProjectId;approvalRequired=$ApprovalRequired}
}

function Select-AI5ManusRoute {
    param($Health)
    $appReady = $Health.app -and $Health.app.state -eq 'READY'
    $webReady = $Health.web -and $Health.web.state -eq 'READY'
    $configuredPreference = [string]$Health.preferredRoute
    if ($configuredPreference -eq 'WEB' -and $webReady) { return [ordered]@{preferred='WEB';selected='WEB';fallback=$(if($appReady){'APP'}else{''});singleDispatch=$true} }
    if ($configuredPreference -eq 'APP' -and $appReady) { return [ordered]@{preferred='APP';selected='APP';fallback=$(if($webReady){'WEB'}else{''});singleDispatch=$true} }
    if ($appReady) { return [ordered]@{preferred='APP';selected='APP';fallback=$(if($webReady){'WEB'}else{''});singleDispatch=$true} }
    if ($webReady) { return [ordered]@{preferred='WEB';selected='WEB';fallback='';singleDispatch=$true} }
    [ordered]@{preferred='';selected='';fallback='';singleDispatch=$true}
}

function ConvertTo-AI5ManusResult {
    param($Request,[string]$Status,[string]$Summary,[array]$Actions=@(),[array]$Evidence=@(),[array]$Warnings=@(),[bool]$NeedsApproval=$false)
    if ($Status -notin @('SUCCESS','FAILED','BLOCKED','AUTH_REQUIRED','APPROVAL_REQUIRED')) { throw 'invalid_manus_status' }
    if ([string]::IsNullOrWhiteSpace($Summary)) { throw 'manus_summary_required' }
    [ordered]@{status=$Status;summary=$Summary;actions=@($Actions);evidence=@($Evidence);warnings=@($Warnings);needsApproval=$NeedsApproval}
}

function New-AI5ManusDispatchPlan {
    param($Task,$Health)
    $route=Select-AI5ManusRoute $Health
    if(!$Health.available-or![string]$route.selected){return [ordered]@{accepted=$false;route='';fallback='';reason='manus_route_unavailable';attempted=$false}}
    [ordered]@{accepted=$true;route=$route.selected;fallback=$route.fallback;reason='private_result_bus_dispatch';attempted=$true;taskId=[string]$Task.taskId;createdAt=[DateTime]::UtcNow.ToString('o')}
}

function ConvertFrom-AI5ManusBusResult {
    param($BusResult)
    $passed=[string]$BusResult.result-eq'PASS'
    [ordered]@{task_id=[string]$BusResult.task_id;agent='manus';status=$(if($passed){'SUCCESS'}else{'FAILED'});summary=[string]$BusResult.summary;actions=@($BusResult.actions);evidence=@($BusResult.evidence);tests=@($BusResult.tests);changedFiles=@();issues=@($BusResult.blockers);recommendation=[string]$BusResult.recommended_next_action;needsRework=!$passed;needsApproval=[bool]$BusResult.approval_required;failureReason=$(if($passed){$null}else{(@($BusResult.blockers)-join' / ')});needs_human=[bool]$BusResult.approval_required;userActionRequired=[bool]$BusResult.approval_required;retryable=!$passed}
}

function Get-AI5ManusHealth {
    $base=Get-AI5SpecialistHealth 'manus'
    $appState=if($base.appState){[string]$base.appState}elseif($base.connection-match'windows_app'){'READY'}else{'OFFLINE'}
    $webState=if($base.webState){[string]$base.webState}elseif($base.connection-match'chrome'){'READY'}else{'OFFLINE'}
    $health=[ordered]@{
        available=[bool]($base.available-and($appState-eq'READY'-or$webState-eq'READY'))
        connection=$base.connection
        quota=$base.quota
        checked_at=$base.checked_at
        preferredRoute=$base.preferredRoute
        app=[ordered]@{state=$appState;automation=$base.appAutomation;identity=$base.appIdentity;version=$base.appVersion;publisher=$base.publisher;source=$base.installSource;authenticated=[bool]$base.appAuthenticated}
        web=[ordered]@{state=$webState;authenticated=[bool]$base.webAuthenticated}
    }
    $health.route=Select-AI5ManusRoute $health
    $health
}
