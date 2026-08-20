$ErrorActionPreference='Stop';$server=Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'adapters\ManusAdapter.ps1'))))
$request=New-AI5ManusRequest 'task-manus-1' 'MANUS_AI5_HUB_OK を返して' 'read_only' 'ai5-hub' $false
if($request.taskId-ne'task-manus-1'-or$request.mode-ne'read_only'-or$request.approvalRequired){throw'request contract invalid'}
$route=Select-AI5ManusRoute ([pscustomobject]@{app=[pscustomobject]@{state='READY'};web=[pscustomobject]@{state='READY'}})
if($route.selected-ne'APP'-or$route.fallback-ne'WEB'-or!$route.singleDispatch){throw'app preferred route invalid'}
$measuredPreference=Select-AI5ManusRoute ([pscustomobject]@{preferredRoute='WEB';app=[pscustomobject]@{state='READY'};web=[pscustomobject]@{state='READY'}})
if($measuredPreference.selected-ne'WEB'-or$measuredPreference.fallback-ne'APP'-or!$measuredPreference.singleDispatch){throw'measured preference invalid'}
$dispatch=New-AI5ManusDispatchPlan ([pscustomobject]@{taskId='task-manus-1'}) ([pscustomobject]@{available=$true;preferredRoute='WEB';app=[pscustomobject]@{state='READY'};web=[pscustomobject]@{state='READY'}})
if(!$dispatch.accepted-or$dispatch.route-ne'WEB'-or$dispatch.fallback-ne'APP'-or!$dispatch.attempted){throw'direct dispatch plan invalid'}
$fallback=Select-AI5ManusRoute ([pscustomobject]@{app=[pscustomobject]@{state='ERROR'};web=[pscustomobject]@{state='READY'}})
if($fallback.selected-ne'WEB'-or!$fallback.singleDispatch){throw'web fallback invalid'}
$result=ConvertTo-AI5ManusResult $request 'SUCCESS' 'MANUS_AI5_HUB_OK' @('read-only prompt') @('exact response') @() $false
if($result.status-ne'SUCCESS'-or$result.needsApproval-or$result.evidence.Count-ne1){throw'result contract invalid'}
$busResult=ConvertFrom-AI5ManusBusResult ([pscustomobject]@{task_id='task-manus-1';result='PASS';summary='MANUS_AI5_HUB_OK';actions=@();evidence=@('exact');tests=@('PASS');blockers=@();approval_required=$false})
if($busResult.agent-ne'manus'-or$busResult.status-ne'SUCCESS'-or$busResult.needsRework){throw'bus result conversion invalid'}
try{New-AI5ManusRequest 'task-manus-write' 'publish' 'execution' 'ai5-hub' $false;throw'unsafe execution allowed'}catch{if($_.Exception.Message-eq'unsafe execution allowed'){throw}}
'MANUS_ADAPTER_TESTS_OK'
