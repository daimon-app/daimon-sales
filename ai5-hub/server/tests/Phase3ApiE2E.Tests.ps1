$ErrorActionPreference='Stop'
$server=Split-Path $PSScriptRoot
$port=43126
$base="http://127.0.0.1:$port"
$out=Join-Path ([IO.Path]::GetTempPath()) 'ai5-phase3-e2e.out'
$err=Join-Path ([IO.Path]::GetTempPath()) 'ai5-phase3-e2e.err'
$previousMock=$env:AI5_MOCK
$env:AI5_MOCK='true'
$process=$null
try {
  $process=Start-Process -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList @('-NoProfile','-File',(Join-Path $server 'server.ps1'),'-Port',$port) -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
  $ready=$false
  foreach($attempt in 1..40){try{$health=Invoke-RestMethod "$base/api/health" -TimeoutSec 1;if($health.ok){$ready=$true;break}}catch{};Start-Sleep -Milliseconds 150}
  if(!$ready){throw "server did not start: $(Get-Content -Raw $err -ErrorAction SilentlyContinue)"}
  $session=Invoke-RestMethod "$base/api/session"
  if(!$session.authenticated-or!$session.local){throw 'loopback session failed'}
  $csrf=$health.csrfToken
  $headers=@{'X-AI5-CSRF'=$csrf;'Idempotency-Key'=[guid]::NewGuid().ToString('N')}
  $danger=Invoke-RestMethod "$base/api/tasks" -Method Post -Headers $headers -ContentType 'application/json' -Body (@{message='本番公開して購入する';source='phase3-e2e'}|ConvertTo-Json)
  if($danger.status-ne'waiting_approval'-or$danger.approval.zero_review.verdict-ne'NOT_RECOMMENDED'){throw 'Zero pre-approval gate failed'}
  if(!$danger.approvalToken){throw 'approval token missing'}
  $approved=Invoke-RestMethod "$base/api/tasks/$($danger.taskId)/approve" -Method Post -Headers @{'X-AI5-CSRF'=$csrf} -ContentType 'application/json' -Body (@{approvalToken=$danger.approvalToken}|ConvertTo-Json)
  if($approved.status-notin@('queued','completed')){throw 'HUB approval did not continue'}
  $safe=Invoke-RestMethod "$base/api/tasks" -Method Post -Headers @{'X-AI5-CSRF'=$csrf;'Idempotency-Key'=[guid]::NewGuid().ToString('N')} -ContentType 'application/json' -Body (@{message='過去の資料と現在の実装に矛盾がないか確認して';source='phase3-e2e'}|ConvertTo-Json)
  if(!$safe.field_mode-or$safe.field_decision.action-ne'AUTO_CONTINUE'){throw 'Field Mode auto continue failed'}
  if($safe.execution_plan.single_writer-ne'codex'){throw 'Single Writer plan missing'}
  $direct=Invoke-RestMethod "$base/api/tasks" -Method Post -Headers @{'X-AI5-CSRF'=$csrf;'Idempotency-Key'=[guid]::NewGuid().ToString('N')} -ContentType 'application/json' -Body (@{message='現在のGit statusを確認して';target='codex';source='phase3-e2e'}|ConvertTo-Json)
  if($direct.requested_target-ne'codex'-or$direct.routing_mode-ne'direct_via_zero'){throw 'direct target API contract failed'}
  $command=Invoke-RestMethod "$base/api/command-center"
  if(!$command.agents.zero-or!$command.agents.codex-or!$command.agents.notebooklm){throw 'command center health missing'}
  try{Invoke-RestMethod "$base/api/shell" -TimeoutSec 2;throw 'arbitrary shell endpoint exposed'}catch{if($_.Exception.Message-eq'arbitrary shell endpoint exposed'){throw}}
  'PHASE3_API_E2E_TESTS_OK'
} finally {
  if($process-and!$process.HasExited){Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue;$process.WaitForExit()}
  if($null-eq$previousMock){Remove-Item Env:AI5_MOCK -ErrorAction SilentlyContinue}else{$env:AI5_MOCK=$previousMock}
  Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
}
