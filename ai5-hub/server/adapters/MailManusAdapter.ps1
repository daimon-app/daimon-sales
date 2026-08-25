function Get-AI5ManusStateRank([string]$State){@{CREATED=0;MAIL_QUEUED=1;MAIL_SENT=2;MANUS_RECEIVED=3;MANUS_TASK_CREATED=4;EXECUTING=5;RESULT_RETURNED=6;RESULT_VERIFIED=7;COMPLETED=8}[$State]}
function Select-AI5ManusRoute {param($Health)
  $mail=$Health.mail-and$Health.mail.state-eq'READY';$direct=$Health.direct-and$Health.direct.state-eq'READY'-and[bool]$Health.direct.verified;$app=$Health.app-and$Health.app.state-eq'READY';$web=$Health.web-and$Health.web.state-eq'READY'
  if($mail){return [ordered]@{preferred='MAIL_MANUS';selected='MAIL_MANUS';secondary=$(if($direct){'DIRECT'}else{''});fallback=$(if($app){'APP'}elseif($web){'WEB'}else{''});singleDispatch=$true}}
  if($direct){return [ordered]@{preferred='DIRECT';selected='DIRECT';secondary='';fallback=$(if($app){'APP'}elseif($web){'WEB'}else{''});singleDispatch=$true}}
  if($app){return [ordered]@{preferred='APP';selected='APP';secondary='';fallback=$(if($web){'WEB'}else{''});singleDispatch=$true}}
  if($web){return [ordered]@{preferred='WEB';selected='WEB';secondary='';fallback='';singleDispatch=$true}}
  [ordered]@{preferred='';selected='';secondary='';fallback='';singleDispatch=$true}
}
function New-AI5MailManusEnvelope {param($Request,[string]$Repository,[string]$CanonicalFile,[array]$AllowedActions=@('READ'),[array]$ProhibitedActions=@('PUBLISH','DELETE','SECRET_ACCESS'),[array]$ExpectedOutput=@('RESULT','EVIDENCE'))
  if((@($Request.taskId,$Request.correlationId,$Request.objective,$Request.projectId,$Repository,$CanonicalFile)+$AllowedActions+$ProhibitedActions+$ExpectedOutput)-join' '-match'(?i)(password|api[_ -]?token|private[_ -]?key|otp|access[_ -]?key)\s*[:=]'){throw 'secret_material_rejected'}
  $subject="[AI5][$($Request.taskId)][$($Request.correlationId)] Manus task";$body=@("TASK_ID: $($Request.taskId)","CORRELATION_ID: $($Request.correlationId)","PROJECT: $($Request.projectId)","PURPOSE: $($Request.objective)","CANONICAL_REPOSITORY: $Repository","CANONICAL_FILE: $CanonicalFile","READ_WRITE_SCOPE: $($Request.mode)","ALLOWED_ACTIONS: $($AllowedActions-join', ')","PROHIBITED_ACTIONS: $($ProhibitedActions-join', ')","EXPECTED_OUTPUT: $($ExpectedOutput-join', ')",'EVIDENCE: cite canonical path and commit; never return secrets')-join"`n";[ordered]@{subject=$subject;body=$body;taskId=$Request.taskId;correlationId=$Request.correlationId}
}
function Set-AI5ManusDispatchState {param($Record,[string]$State);if($null-eq(Get-AI5ManusStateRank $State)){throw 'invalid_manus_dispatch_state'};if($Record.state-and(Get-AI5ManusStateRank $State)-lt(Get-AI5ManusStateRank $Record.state)){throw 'manus_state_regression_blocked'};$Record.state=$State;$Record.updatedAt=[DateTime]::UtcNow.ToString('o');$Record}
function Test-AI5ManusDuplicate {param($Record,[string]$TaskId,[string]$CorrelationId);[bool]($Record-and$Record.taskId-eq$TaskId-and$Record.correlationId-eq$CorrelationId-and(Get-AI5ManusStateRank $Record.state)-ge1)}
function New-AI5MailManusDispatchDecision {param($Request,$ExistingRecord,$SentMatch)
  if(Test-AI5ManusDuplicate $ExistingRecord $Request.taskId $Request.correlationId){return [ordered]@{send=$false;reason='duplicate_blocked';record=$ExistingRecord}}
  if($SentMatch-and$SentMatch.taskId-eq$Request.taskId-and$SentMatch.correlationId-eq$Request.correlationId){return [ordered]@{send=$false;reason='sent_state_reconciled';record=[ordered]@{taskId=$Request.taskId;correlationId=$Request.correlationId;mailMessageId=$SentMatch.mailMessageId;mailThreadId=$SentMatch.mailThreadId;manusTaskId=$SentMatch.manusTaskId;state='MAIL_SENT';retryCount=0}}}
  [ordered]@{send=$true;reason='new_dispatch';record=[ordered]@{taskId=$Request.taskId;correlationId=$Request.correlationId;mailMessageId='';mailThreadId='';manusTaskId='';state='MAIL_QUEUED';retryCount=0}}
}
function Test-AI5ManusResultCorrelation {param($Record,$Reply);[bool]($Record-and$Reply-and$Reply.taskId-eq$Record.taskId-and$Reply.correlationId-eq$Record.correlationId-and(($Reply.mailThreadId-and$Reply.mailThreadId-eq$Record.mailThreadId)-or($Reply.inReplyTo-and$Reply.inReplyTo-eq$Record.mailMessageId)))}
