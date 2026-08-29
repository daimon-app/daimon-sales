$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\security\MobileSecurity.ps1')
. (Join-Path $PSScriptRoot '..\approval\ZeroApproval.ps1')
. (Join-Path $PSScriptRoot '..\approval\ApprovalPolicy.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('ai5-approval-'+[guid]::NewGuid().ToString('N'))
try {
  Initialize-AI5MobileSecurity $root;Initialize-AI5ApprovalPolicy $root
  function New-PolicyTask([string]$id,[string]$message){[pscustomobject]@{taskId=$id;project_id='ai5-hub';message=$message;objective=$message;route=[pscustomobject]@{approvalType=$null};status='queued';canonical_status='RECEIVED';requiresApproval=$false;approval_level='GREEN'}}
  $l0=Resolve-AI5TaskApprovalPolicy (New-PolicyTask 'level0' 'read-only監査とtestを実行')
  if($l0.requiresApproval-or$l0.approvalPolicy.level-ne0){throw'LEVEL 0 failed'}
  $l1=Resolve-AI5TaskApprovalPolicy (New-PolicyTask 'level1' '新しいSNS投稿を公開')
  if(!$l1.requiresApproval-or$l1.approvalPolicy.level-ne1-or$l1.approval.ownerOperationRequired){throw'LEVEL 1 failed'}
  $receipt=Approve-AI5ApprovalRequest 'level1' 'test-owner';if($receipt.status-ne'approved'-or!$receipt.receiptId){throw'approval receipt failed'}
  $reuse=Resolve-AI5TaskApprovalPolicy (New-PolicyTask 'level1-reuse' '新しいSNS投稿を公開')
  if($reuse.requiresApproval-or$reuse.approval.type-ne'existing_scope'){throw'exact scope reuse failed'}
  $l2=Resolve-AI5TaskApprovalPolicy (New-PolicyTask 'level2' '4,980円の有料契約を購入')
  if(!$l2.approval.ownerOperationRequired-or!$l2.approvalPolicy.money){throw'LEVEL 2 money protection failed'}
  try{Approve-AI5ApprovalRequest 'level2' 'test-owner';throw'LEVEL 2 approval was allowed'}catch{if($_.Exception.Message-ne'owner_operation_required'){throw}}
  $registry=@([pscustomobject]@{accountId='daimon-sales-01';channelId='UC-DAIMON';name='DAIMON公式'})
  $verified=Test-AI5AccountEvidence ([pscustomobject]@{accountId='daimon-sales-01';channelId='';accountName='DAIMON'}) $registry
  if($verified.status-ne'VERIFIED_BY_AI5'-or$verified.ownerGate-or!$verified.postingAllowed){throw'AI account verification failed'}
  $wrong=Test-AI5AccountEvidence ([pscustomobject]@{accountId='personal';accountName='鉄兵 個人';isPersonal=$true}) $registry
  if($wrong.status-ne'WRONG_ACCOUNT'-or$wrong.postingAllowed){throw'wrong account protection failed'}
  $unknown=Test-AI5AccountEvidence ([pscustomobject]@{accountName='不明'}) $registry
  if($unknown.status-ne'UNRESOLVED'-or$unknown.ownerGate){throw'unresolved account isolation failed'}
  'APPROVAL_POLICY_TESTS_PASS'
} finally {Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue}
