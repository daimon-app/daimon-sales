$ErrorActionPreference='Stop'
$server=Split-Path $PSScriptRoot
$port=43126
$base="http://127.0.0.1:$port"
$out=Join-Path ([IO.Path]::GetTempPath()) 'ai5-phase3-e2e.out'
$err=Join-Path ([IO.Path]::GetTempPath()) 'ai5-phase3-e2e.err'
$previousMock=$env:AI5_MOCK
$previousDataRoot=$env:AI5_SERVER_DATA_ROOT
$testDataRoot=Join-Path ([IO.Path]::GetTempPath()) ('ai5-phase3-'+[guid]::NewGuid().ToString('N'))
$env:AI5_MOCK='true'
$env:AI5_SERVER_DATA_ROOT=$testDataRoot
$process=$null
try {
  $process=Start-Process -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList @('-NoProfile','-File',(Join-Path $server 'server.ps1'),'-Port',$port) -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
  $ready=$false
  foreach($attempt in 1..120){try{$health=Invoke-RestMethod "$base/api/health" -TimeoutSec 1;if($health.ok){$ready=$true;break}}catch{};Start-Sleep -Milliseconds 150}
  if(!$ready){throw "server did not start: $(Get-Content -Raw $err -ErrorAction SilentlyContinue)"}
  $session=Invoke-RestMethod "$base/api/session"
  if(!$session.authenticated-or!$session.local){throw 'loopback session failed'}
  $csrf=$health.csrfToken
  $headers=@{'X-AI5-CSRF'=$csrf;'Idempotency-Key'=[guid]::NewGuid().ToString('N')}
  $danger=Invoke-RestMethod "$base/api/tasks" -Method Post -Headers $headers -ContentType 'application/json' -Body (@{message='新しいSNS投稿を公開する';source='phase3-e2e';product='Kumiko Manufacturing Starter';accountService='DAIMON公式SNS';amount='0円';externalImpact='DAIMON公式SNSへ1件公開';reversible=$true;approvalReason='新規公開の対象と影響を本人が確認するため';afterApproval='指定投稿を1件公開しReceiptを保存する'}|ConvertTo-Json)
  if($danger.status-ne'waiting_approval'-or$danger.approval.level-ne1){throw 'LEVEL 1 pre-approval gate failed'}
  if(!$danger.approval.contextComplete-or@($danger.approval.context.psobject.Properties).Count-ne9){throw 'approval context contract failed'}
  if(!$danger.approvalToken){throw 'approval token missing'}
  $approved=Invoke-RestMethod "$base/api/tasks/$($danger.taskId)/approve" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body (@{approvalToken=$danger.approvalToken}|ConvertTo-Json)
  if($approved.status-notin@('queued','completed')){throw 'HUB approval did not continue'}
  $incomplete=Invoke-RestMethod "$base/api/tasks" -Method Post -Headers @{'X-AI5-CSRF'=$csrf;'Idempotency-Key'=[guid]::NewGuid().ToString('N')} -ContentType 'application/json' -Body (@{message='新しいSNS投稿を公開する';source='phase3-e2e'}|ConvertTo-Json)
  if($incomplete.approval.contextComplete-or$incomplete.approvalToken){throw 'incomplete context exposed approval action'}
  try{Invoke-RestMethod "$base/api/tasks/$($incomplete.taskId)/approve" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body '{}';throw 'incomplete approval was allowed'}catch{if($_.Exception.Message-eq'incomplete approval was allowed'){throw}}
  $mock=Invoke-RestMethod "$base/api/tasks" -Method Post -Headers @{'X-AI5-CSRF'=$csrf;'Idempotency-Key'=[guid]::NewGuid().ToString('N')} -ContentType 'application/json' -Body (@{message='模擬E2E TEST。外部操作0、金銭0。';source='phase3-e2e'}|ConvertTo-Json)
  if($mock.requiresApproval-or$mock.approval.type-ne'safe_mock_test'){throw 'safe mock E2E raised Owner Gate'}
  $protected=Invoke-RestMethod "$base/api/tasks" -Method Post -Headers @{'X-AI5-CSRF'=$csrf;'Idempotency-Key'=[guid]::NewGuid().ToString('N')} -ContentType 'application/json' -Body (@{message='4,980円の有料契約を購入する';source='phase3-e2e';product='AI5有料サービス';accountService='対象契約サービス';amount='4,980円';externalImpact='有料契約が開始される';reversible=$true;approvalReason='実支出と有料契約は本人しか承認できないため';afterApproval='本人操作完了後にReceiptを照合する'}|ConvertTo-Json)
  if($protected.approval.level-ne2-or!$protected.approval.ownerOperationRequired){throw 'LEVEL 2 protection missing'}
  try{Invoke-RestMethod "$base/api/tasks/$($protected.taskId)/approve" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body (@{approvalToken=$protected.approvalToken}|ConvertTo-Json);throw 'LEVEL 2 proxy approval allowed'}catch{if($_.Exception.Message-eq'LEVEL 2 proxy approval allowed'){throw}}
  $safe=Invoke-RestMethod "$base/api/tasks" -Method Post -Headers @{'X-AI5-CSRF'=$csrf;'Idempotency-Key'=[guid]::NewGuid().ToString('N')} -ContentType 'application/json' -Body (@{message='過去の資料と現在の実装に矛盾がないか確認して';source='phase3-e2e'}|ConvertTo-Json)
  if(!$safe.field_mode-or$safe.field_decision.action-ne'AUTO_CONTINUE'){throw 'Field Mode auto continue failed'}
  if($safe.execution_plan.single_writer-ne'codex'){throw 'Single Writer plan missing'}
  $direct=Invoke-RestMethod "$base/api/tasks" -Method Post -Headers @{'X-AI5-CSRF'=$csrf;'Idempotency-Key'=[guid]::NewGuid().ToString('N')} -ContentType 'application/json' -Body (@{message='現在のGit statusを確認して';target='codex';source='phase3-e2e'}|ConvertTo-Json)
  if($direct.requested_target-ne'codex'-or$direct.routing_mode-ne'direct_via_zero'){throw 'direct target API contract failed'}
  $long='AI5 HUB long message test '+('あ'*9000);$sha=[Security.Cryptography.SHA256]::Create();try{$longHash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($long)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()};$draftId=[guid]::NewGuid().ToString('N');$pieces=@($long.Substring(0,4000),$long.Substring(4000,4000),$long.Substring(8000))
  $draft=Invoke-RestMethod "$base/api/message-drafts" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body (@{messageId=$draftId;totalChunks=3;totalLength=$long.Length;contentHash=$longHash}|ConvertTo-Json)
  foreach($index in 0..2){$sha=[Security.Cryptography.SHA256]::Create();try{$chunkHash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($pieces[$index])))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()};$chunk=Invoke-RestMethod "$base/api/message-drafts/$draftId/chunks/$index" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body (@{content=$pieces[$index];chunkHash=$chunkHash}|ConvertTo-Json);$null=Invoke-RestMethod "$base/api/message-drafts/$draftId/chunks/$index" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body (@{content=$pieces[$index];chunkHash=$chunkHash}|ConvertTo-Json)}
  $longTask=Invoke-RestMethod "$base/api/message-drafts/$draftId/commit" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body (@{target='auto';source='phase3-e2e';conversationId='long-e2e'}|ConvertTo-Json);$sameLongTask=Invoke-RestMethod "$base/api/message-drafts/$draftId/commit" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body '{}'
  if($longTask.taskId-ne$sameLongTask.taskId-or$longTask.original_message_length-ne$long.Length-or$longTask.long_message_id-ne$draftId){throw 'long message did not create exactly one intact task'}
  $command=Invoke-RestMethod "$base/api/command-center"
  if(!$command.agents.zero-or!$command.agents.codex-or!$command.agents.notebooklm){throw 'command center health missing'}
  $chat=Invoke-RestMethod "$base/api/chat" -Headers @{'X-AI5-Chat-Level'='NORMAL'}
  if(!$chat.messages-or!($chat.messages|Where-Object{$_.agent-eq'zero'})){throw 'durable AI5 LINE report missing'}
  $busId='e2e-'+[guid]::NewGuid().ToString('N');$busTask=Invoke-RestMethod "$base/api/github-bus/tasks" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body (@{task_id=$busId;project_id='p02';assigned_ai='manus';writer='manus';objective='LP QA';instructions='read only';acceptance_criteria=@('PASS');max_retry=3}|ConvertTo-Json)
  if($busTask.status-ne'QUEUED'){throw 'GitHub Task Bus API failed'};$claim=Invoke-RestMethod "$base/api/github-bus/tasks/$busId/claim" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body (@{ai='manus'}|ConvertTo-Json);if($claim.owner-ne'manus'){throw 'GitHub Task claim API failed'}
  $busResult=Invoke-RestMethod "$base/api/github-bus/results" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body (@{task_id=$busId;ai='manus';result='PASS';summary='LP PASS';evidence=@('qa');tests=@('PASS')}|ConvertTo-Json);if($busResult.saved.duplicate-or$busResult.collector.processed-ne1){throw 'GitHub Result Collector API failed'}
  $inbox=Invoke-RestMethod "$base/api/github-bus/inbox";if(!($inbox.items|Where-Object{$_.task_id-eq$busId-and$_.decision-eq'PASS'})){throw 'Zero Inbox API failed'};$busStatus=Invoke-RestMethod "$base/api/github-bus/status";if($busStatus.remoteEnabled-or$busStatus.mode-ne'GITHUB_DEGRADED'){throw 'public-safe degraded mode failed'}
  $busChat=Invoke-RestMethod "$base/api/chat" -Headers @{'X-AI5-Chat-Level'='NORMAL'};if(!($busChat.messages|Where-Object{$_.taskId-eq$busId-and$_.kind-eq'github_result'})){throw 'GitHub Result LINE timeline failed'}
  $project=Invoke-RestMethod "$base/api/projects/ai5-hub";if($null-eq$project.githubResultLoop-or$null-eq$project.autonomousLoop){throw 'Project Control autonomous Result Loop integration failed'}
  try{Invoke-RestMethod "$base/api/shell" -TimeoutSec 2;throw 'arbitrary shell endpoint exposed'}catch{if($_.Exception.Message-eq'arbitrary shell endpoint exposed'){throw}}
  'PHASE3_API_E2E_TESTS_OK'
} finally {
  if($process-and!$process.HasExited){Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue;$process.WaitForExit()}
  if($null-eq$previousMock){Remove-Item Env:AI5_MOCK -ErrorAction SilentlyContinue}else{$env:AI5_MOCK=$previousMock}
  if($null-eq$previousDataRoot){Remove-Item Env:AI5_SERVER_DATA_ROOT -ErrorAction SilentlyContinue}else{$env:AI5_SERVER_DATA_ROOT=$previousDataRoot}
  Remove-Item -LiteralPath $testDataRoot -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
}
