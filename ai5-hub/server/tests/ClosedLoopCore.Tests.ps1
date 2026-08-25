$ErrorActionPreference='Stop';$server=Split-Path $PSScriptRoot;. (Join-Path $server 'orchestrator\ClosedLoopCore.ps1')
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('ai5-closed-loop-'+[Guid]::NewGuid().ToString('N'));Initialize-AI5ClosedLoopCore $tmp
function A($v,$m){if(!$v){throw $m}}
try{
  $task=[pscustomobject]@{TASK_ID='task-1';CORRELATION_ID='corr-1';PROJECT_ID='project-1'};$first=Enter-AI5PersistentClaim $task 'codex' 300 3;A $first.claimed 'initial atomic claim failed'
  $second=Enter-AI5PersistentClaim $task 'claude_api' 300 3;A (!$second.claimed-and$second.reason-eq'active_lease') 'duplicate claim not blocked'
  $lock=Enter-AI5ProjectWriterLease 'project-1' 'task-1' 'codex' 300;A $lock.acquired 'writer lease failed';$lock2=Enter-AI5ProjectWriterLease 'project-1' 'task-2' 'claude_api' 300;A (!$lock2.acquired-and$lock2.reason-eq'single_writer_active') 'single writer violated'
  $result=[pscustomobject]@{TASK_ID='task-1';CORRELATION_ID='corr-1';AGENT='codex';STATUS='PASS';SUMMARY='ok';EVIDENCE=@('test');ATTEMPT=1;FINISHED_AT=[DateTime]::UtcNow.ToString('o')}
  A (Save-AI5ClosedLoopResult $result).accepted 'result not accepted';A (Save-AI5ClosedLoopResult $result).duplicate 'duplicate result not blocked'
  $claimPath=Join-Path $script:ClosedLoopClaims 'task-1--corr-1.json';$expired=Get-Content -Raw $claimPath|ConvertFrom-Json;$expired.lease_expires_at=[DateTime]::UtcNow.AddSeconds(-1).ToString('o');$expired.lease_expires_unix_ms=[DateTimeOffset]::UtcNow.AddSeconds(-1).ToUnixTimeMilliseconds();Write-AI5AtomicJson $claimPath $expired
  $recovered=Enter-AI5PersistentClaim $task 'claude_api' 300 3;A ($recovered.claimed-and$recovered.recovered-and$recovered.record.attempt-eq2) 'crash recovery failed';$recovered.record.lease_expires_at=[DateTime]::UtcNow.AddSeconds(-1).ToString('o');$recovered.record.lease_expires_unix_ms=[DateTimeOffset]::UtcNow.AddSeconds(-1).ToUnixTimeMilliseconds();Write-AI5AtomicJson $claimPath $recovered.record
  $third=Enter-AI5PersistentClaim $task 'gemini_api' 300 3;A ($third.claimed-and$third.record.attempt-eq3) 'third retry failed';$third.record.lease_expires_at=[DateTime]::UtcNow.AddSeconds(-1).ToString('o');$third.record.lease_expires_unix_ms=[DateTimeOffset]::UtcNow.AddSeconds(-1).ToUnixTimeMilliseconds();Write-AI5AtomicJson $claimPath $third.record
  $stop=Enter-AI5PersistentClaim $task 'codex' 300 3;A (!$stop.claimed-and$stop.reason-eq'retry_ceiling') 'retry ceiling failed'
  A ((Get-AI5ApiNodeStatus claude_api).status-in@('NOT_WIRED','WAITING_OWNER_AUTH')) 'Claude state invalid';A ((Get-AI5ApiNodeStatus gemini_api).status-in@('NOT_WIRED','WAITING_OWNER_AUTH')) 'Gemini state invalid';'CLOSED_LOOP_CORE_TESTS_OK'
}finally{Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
