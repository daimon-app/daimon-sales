$ErrorActionPreference='Stop';$server=Split-Path $PSScriptRoot
. (Join-Path $server 'adapters\ManusAdapter.ps1')
. (Join-Path $server 'adapters\MailManusAdapter.ps1')
$request=New-AI5ManusRequest 'task-manus-1' 'MANUS_AI5_HUB_OK を返して' 'read_only' 'ai5-hub' $false
if($request.taskId-ne'task-manus-1'-or$request.mode-ne'read_only'-or$request.approvalRequired){throw 'request contract invalid'}
$route=Select-AI5ManusRoute ([pscustomobject]@{mail=[pscustomobject]@{state='READY'};app=[pscustomobject]@{state='READY'};web=[pscustomobject]@{state='READY'}})
if($route.selected-ne'MAIL_MANUS'-or$route.fallback-ne'APP'-or!$route.singleDispatch){throw 'mail primary route invalid'}
$measuredPreference=Select-AI5ManusRoute ([pscustomobject]@{mail=[pscustomobject]@{state='OFFLINE'};app=[pscustomobject]@{state='READY'};web=[pscustomobject]@{state='READY'}})
if($measuredPreference.selected-ne'APP'-or$measuredPreference.fallback-ne'WEB'-or!$measuredPreference.singleDispatch){throw 'GUI rollback route invalid'}
$dispatch=New-AI5ManusDispatchPlan ([pscustomobject]@{taskId='task-manus-1'}) ([pscustomobject]@{available=$true;preferredRoute='WEB';app=[pscustomobject]@{state='READY'};web=[pscustomobject]@{state='READY'}})
if(!$dispatch.accepted-or$dispatch.route-ne'APP'-or$dispatch.fallback-ne'WEB'-or!$dispatch.attempted){throw 'direct dispatch plan invalid'}
$fallback=Select-AI5ManusRoute ([pscustomobject]@{app=[pscustomobject]@{state='ERROR'};web=[pscustomobject]@{state='READY'}})
if($fallback.selected-ne'WEB'-or!$fallback.singleDispatch){throw 'web fallback invalid'}
$result=ConvertTo-AI5ManusResult $request 'SUCCESS' 'MANUS_AI5_HUB_OK' @('read-only prompt') @('exact response') @() $false
if($result.status-ne'SUCCESS'-or$result.needsApproval-or$result.evidence.Count-ne1){throw 'result contract invalid'}
$busResult=ConvertFrom-AI5ManusBusResult ([pscustomobject]@{task_id='task-manus-1';result='PASS';summary='MANUS_AI5_HUB_OK';actions=@();evidence=@('exact');tests=@('PASS');blockers=@();approval_required=$false})
if($busResult.agent-ne'manus'-or$busResult.status-ne'SUCCESS'-or$busResult.needsRework){throw 'bus result conversion invalid'}
try{New-AI5ManusRequest 'task-manus-write' 'publish' 'execution' 'ai5-hub' $false;throw 'unsafe execution allowed'}catch{if($_.Exception.Message-eq'unsafe execution allowed'){throw}}
$request|Add-Member correlationId 'corr-1';$mail=New-AI5MailManusEnvelope $request 'daimon-app/daimon-morning-sales' 'sales/MASTER.md'
if($mail.body-notmatch'TASK_ID: task-manus-1'-or$mail.body-notmatch'CORRELATION_ID: corr-1'){throw 'mail task format invalid'}
$decision=New-AI5MailManusDispatchDecision $request $null $null;if(!$decision.send){throw 'new mail dispatch blocked'}
$record=$decision.record;$record.mailMessageId='m1';$record.mailThreadId='th1';Set-AI5ManusDispatchState $record 'MAIL_SENT'|Out-Null
$duplicate=New-AI5MailManusDispatchDecision $request $record $null;if($duplicate.send-or$duplicate.reason-ne'duplicate_blocked'){throw 'duplicate mail task allowed'}
$reconciled=New-AI5MailManusDispatchDecision $request $null ([pscustomobject]@{taskId='task-manus-1';correlationId='corr-1';mailMessageId='m1';mailThreadId='th1';manusTaskId=''})
if($reconciled.send-or$reconciled.reason-ne'sent_state_reconciled'){throw 'sent mailbox reconciliation failed'}
if(!(Test-AI5ManusResultCorrelation $record ([pscustomobject]@{taskId='task-manus-1';correlationId='corr-1';mailThreadId='th1';inReplyTo=''}))){throw 'result correlation failed'}
if(Test-AI5ManusResultCorrelation $record ([pscustomobject]@{taskId='task-manus-1';correlationId='wrong';mailThreadId='th1';inReplyTo='' })){throw 'wrong correlation accepted'}
try{Set-AI5ManusDispatchState $record 'CREATED'|Out-Null;throw 'state regression allowed'}catch{if($_.Exception.Message-eq'state regression allowed'){throw}}
try{New-AI5MailManusEnvelope ([pscustomobject]@{taskId='s';correlationId='c';objective=(('pass'+'word')+': secret');projectId='p';mode='read_only'}) 'r' 'f';throw 'secret accepted'}catch{if($_.Exception.Message-eq'secret accepted'){throw}}
'MANUS_ADAPTER_TESTS_OK'
