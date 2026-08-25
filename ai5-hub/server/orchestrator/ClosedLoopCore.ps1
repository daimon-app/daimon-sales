function Initialize-AI5ClosedLoopCore {param([string]$ServerRoot)
  $script:ClosedLoopRoot=Join-Path $ServerRoot 'runtime\closed-loop';$script:ClosedLoopClaims=Join-Path $script:ClosedLoopRoot 'claims';$script:ClosedLoopLocks=Join-Path $script:ClosedLoopRoot 'locks';$script:ClosedLoopResults=Join-Path $script:ClosedLoopRoot 'results'
  @($script:ClosedLoopRoot,$script:ClosedLoopClaims,$script:ClosedLoopLocks,$script:ClosedLoopResults)|ForEach-Object{New-Item -ItemType Directory -Force $_|Out-Null}
}
function Get-AI5ClosedLoopKey([string]$TaskId,[string]$CorrelationId){if($TaskId-notmatch'^[A-Za-z0-9._-]+$'-or$CorrelationId-notmatch'^[A-Za-z0-9._-]+$'){throw 'invalid_task_or_correlation_id'};"$TaskId--$CorrelationId"}
function Write-AI5AtomicJson {param([string]$Path,$Value,[bool]$CreateOnly=$false)
  $json=$Value|ConvertTo-Json -Depth 20;if($CreateOnly){$bytes=[Text.Encoding]::UTF8.GetBytes($json);$stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()};return}
  $tmp="$Path.$([Guid]::NewGuid().ToString('N')).tmp";[IO.File]::WriteAllText($tmp,$json,[Text.UTF8Encoding]::new($false));[IO.File]::Move($tmp,$Path,$true)
}
function Enter-AI5PersistentClaim {param($Task,[string]$Writer,[int]$LeaseSeconds=300,[int]$MaxRetry=3)
  if($MaxRetry -lt 1 -or $MaxRetry -gt 3){throw 'retry_ceiling_invalid'}
  $key=Get-AI5ClosedLoopKey $Task.TASK_ID $Task.CORRELATION_ID
  $path=Join-Path $script:ClosedLoopClaims "$key.json"
  $now=[DateTime]::UtcNow
  $record=[ordered]@{task_id=$Task.TASK_ID;correlation_id=$Task.CORRELATION_ID;project_id=$Task.PROJECT_ID;writer=$Writer;state='CLAIMED';attempt=1;max_retry=$MaxRetry;lease_expires_at=$now.AddSeconds($LeaseSeconds).ToString('o');lease_expires_unix_ms=[DateTimeOffset]::UtcNow.AddSeconds($LeaseSeconds).ToUnixTimeMilliseconds();created_at=$now.ToString('o');updated_at=$now.ToString('o')}
  try {
    Write-AI5AtomicJson $path $record $true
    return [ordered]@{claimed=$true;recovered=$false;record=$record}
  } catch [IO.IOException] {
    $existing=Get-Content -Raw -Encoding UTF8 $path|ConvertFrom-Json
    if($existing.state -in @('RESULT_ACCEPTED','COMPLETED')){return [ordered]@{claimed=$false;reason='already_completed';record=$existing}}
    $nowMs=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    if([long]$existing.lease_expires_unix_ms -gt $nowMs){return [ordered]@{claimed=$false;reason='active_lease';record=$existing}}
    if([int]$existing.attempt -ge [int]$existing.max_retry){return [ordered]@{claimed=$false;reason='retry_ceiling';record=$existing}}
    $existing.writer=$Writer;$existing.state='CLAIMED';$existing.attempt=[int]$existing.attempt+1;$existing.lease_expires_at=$now.AddSeconds($LeaseSeconds).ToString('o');$existing.lease_expires_unix_ms=[DateTimeOffset]::UtcNow.AddSeconds($LeaseSeconds).ToUnixTimeMilliseconds();$existing.updated_at=$now.ToString('o')
    Write-AI5AtomicJson $path $existing
    return [ordered]@{claimed=$true;recovered=$true;record=$existing}
  }
}
function Enter-AI5ProjectWriterLease {param([string]$ProjectId,[string]$TaskId,[string]$Writer,[int]$LeaseSeconds=300)
  $safe=($ProjectId-replace'[^A-Za-z0-9._-]','_');$path=Join-Path $script:ClosedLoopLocks "$safe.json";$now=[DateTime]::UtcNow;$lock=[ordered]@{project_id=$ProjectId;task_id=$TaskId;writer=$Writer;lease_expires_at=$now.AddSeconds($LeaseSeconds).ToString('o');lease_expires_unix_ms=[DateTimeOffset]::UtcNow.AddSeconds($LeaseSeconds).ToUnixTimeMilliseconds()}
  try {Write-AI5AtomicJson $path $lock $true;return [ordered]@{acquired=$true;recovered=$false;lock=$lock}}
  catch [IO.IOException] {$old=Get-Content -Raw -Encoding UTF8 $path|ConvertFrom-Json;$nowMs=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();if([long]$old.lease_expires_unix_ms -gt $nowMs){return [ordered]@{acquired=$false;reason='single_writer_active';lock=$old}};Write-AI5AtomicJson $path $lock;return [ordered]@{acquired=$true;recovered=$true;lock=$lock}}
}
function Save-AI5ClosedLoopResult {param($Result);$key=Get-AI5ClosedLoopKey $Result.TASK_ID $Result.CORRELATION_ID;$path=Join-Path $script:ClosedLoopResults "$key.json";try{Write-AI5AtomicJson $path $Result $true;[ordered]@{accepted=$true;duplicate=$false;path=$path}}catch [IO.IOException]{$existing=Get-Content -Raw -Encoding UTF8 $path|ConvertFrom-Json;[ordered]@{accepted=$false;duplicate=$true;path=$path;existing=$existing}}}
function Get-AI5ApiNodeStatus {param([ValidateSet('claude_api','gemini_api')][string]$Node);$names=if($Node-eq'claude_api'){@('ANTHROPIC_API_KEY','CLAUDE_API_KEY')}else{@('GEMINI_API_KEY','GOOGLE_API_KEY')};$present=$false;foreach($name in $names){if(![string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))){$present=$true}};[ordered]@{node=$Node;status=$(if($present){'NOT_WIRED'}else{'WAITING_OWNER_AUTH'});credential_present=$present;live_verified=$false}}
