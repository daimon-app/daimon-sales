$ErrorActionPreference='Stop'
$server=Split-Path $PSScriptRoot
foreach($module in @('security\MobileSecurity.ps1','approval\ZeroApproval.ps1','approval\ApprovalRouting.ps1','approval\ApprovalPolicy.ps1')){. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server $module))))}
$root=Join-Path ([IO.Path]::GetTempPath()) ('ai5-approval-'+[guid]::NewGuid().ToString('N'))
try {
  Initialize-AI5MobileSecurity $root;Initialize-AI5ApprovalPolicy $root;Initialize-AI5ApprovalRouting $root
  function New-PolicyTask([string]$id,[string]$message){[pscustomobject]@{taskId=$id;project_id='ai5-hub';message=$message;objective=$message;product=$null;taskLabel=$null;accountService=$null;service=$null;account=$null;channel=$null;amount=$null;externalImpact=$null;reversible=$null;approvalReason=$null;afterApproval=$null;whatDoesNotChange=@();ownerAction=$null;expiresAt=$null;idempotencyKey=$id;route=[pscustomobject]@{approvalType=$null};status='queued';canonical_status='RECEIVED';requiresApproval=$false;approval_level='GREEN'}}
  $l0=Resolve-AI5TaskApprovalPolicy (New-PolicyTask 'level0' 'read-only監査とtestを実行')
  if($l0.requiresApproval-or$l0.approvalPolicy.level-ne0){throw'LEVEL 0 failed'}
  $l1Task=New-PolicyTask 'level1' '新しいSNS投稿を公開';$l1Task.product='Kumiko Manufacturing Starter';$l1Task.accountService='DAIMON公式SNS';$l1Task.amount='0円';$l1Task.externalImpact='DAIMON公式SNSへ1件公開';$l1Task.reversible=$true;$l1Task.approvalReason='新規公開の対象と影響を本人が確認するため';$l1Task.afterApproval='指定投稿を1件公開しReceiptを保存する'
  $l1=Resolve-AI5TaskApprovalPolicy $l1Task
  if(!$l1.requiresApproval-or$l1.approvalPolicy.level-ne1-or$l1.approval.ownerOperationRequired-or!$l1.approval.contextComplete){throw'LEVEL 1 failed'}
  if($l1.approvalTask.type-ne'AI5_HUB_APPROVAL_TASK'-or$l1.approvalTask.blocked_scope-ne'THIS_TASK_ONLY'-or$l1.approvalTask.global_state-ne'EXECUTING'){throw'approval routing payload failed'}
  $receipt=Approve-AI5ApprovalRequest 'level1' 'test-owner';if($receipt.status-ne'approved'-or!$receipt.receiptId){throw'approval receipt failed'}
  $reuseTask=New-PolicyTask 'level1-reuse' '新しいSNS投稿を公開';$reuseTask.product='Kumiko Manufacturing Starter';$reuseTask.accountService='DAIMON公式SNS';$reuseTask.amount='0円';$reuseTask.externalImpact='DAIMON公式SNSへ1件公開';$reuseTask.reversible=$true;$reuseTask.approvalReason='新規公開の対象と影響を本人が確認するため';$reuseTask.afterApproval='指定投稿を1件公開しReceiptを保存する'
  $reuse=Resolve-AI5TaskApprovalPolicy $reuseTask
  if($reuse.requiresApproval-or$reuse.approval.type-ne'existing_scope'){throw 'exact scope reuse failed'}
  $main=Resolve-AI5TaskApprovalPolicy (New-PolicyTask 'safe-main' 'main統合。全回帰PASS、競合0、非force、rollback READY、外部公開なし、金銭操作なし、秘密情報なし、重大な不可逆変更なし。')
  if($main.requiresApproval-or$main.approval.type-ne'verified_main_integration'){throw 'verified safe main integration was not LEVEL 0'}
  $mock=Resolve-AI5TaskApprovalPolicy (New-PolicyTask 'safe-mock' '模擬E2E TEST。外部操作0、金銭0。')
  if($mock.requiresApproval-or$mock.approval.type-ne'safe_mock_test'){throw 'safe mock test was not LEVEL 0'}
  $incomplete=Resolve-AI5TaskApprovalPolicy (New-PolicyTask 'incomplete' '新しいSNS投稿を公開')
  if(!$incomplete.requiresApproval-or$incomplete.approval.contextComplete-or$incomplete.approval.contextStatus-ne'APPROVAL_CONTEXT_INCOMPLETE'){throw 'incomplete approval context guard failed'}
  $routePublish=New-PolicyTask 'route-publish' 'Pinterest Organic Pinを設定し、UTMと計測を確認する';$routePublish.route=[pscustomobject]@{approvalType='external_publish'};$routePublish.product='OMIKUJI / FUKU';$routePublish.channel='Pinterest Organic';$routePublish.accountService='Pinterest';$routePublish.amount='0円';$routePublish.externalImpact='Public Pinを1件公開';$routePublish.reversible=$true;$routePublish.approvalReason='第三者向け公開';$routePublish.afterApproval='公開してLive検証';$routePublish=Resolve-AI5TaskApprovalPolicy $routePublish
  if(!$routePublish.requiresApproval-or$routePublish.approvalPolicy.level-ne1-or!$routePublish.approvalPolicy.sound){throw 'router external_publish must remain Level 1 with sound'}
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
