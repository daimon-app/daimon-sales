param(
  [Parameter(Mandatory=$true,Position=0)]
  [ValidateSet('enqueue','run-once','show','doctor')]
  [string]$Command,
  [string]$TaskId,
  [string]$Instruction,
  [string]$Workspace
)
$ErrorActionPreference='Stop'
$PSDefaultParameterValues['Get-Content:Encoding']='UTF8'
$Root=$PSScriptRoot
$Queue=Join-Path $Root 'queue';$Results=Join-Path $Root 'results';$Logs=Join-Path $Root 'logs';$Runtime=Join-Path $Root 'runtime'
@($Queue,$Results,$Logs,$Runtime,(Join-Path $Runtime 'workspace')) | ForEach-Object { New-Item -ItemType Directory -Force $_ | Out-Null }
function Now { [DateTime]::UtcNow.ToString('o') }
function Redact([string]$Value) { if($null -eq $Value){return $null};$Value -replace '(?i)(api[_-]?key|access[_-]?token|password|secret)\s*[:=]\s*([^\s,;]+)','$1=[REDACTED]' }
function Safe([string]$Value) { $Value -replace '[^A-Za-z0-9_.-]','_' }
function PathOf([string]$Id) { Join-Path $Queue ((Safe $Id)+'.json') }
function WriteJ($Value,[string]$Path) { $Value|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $Path -Encoding UTF8 }
function Log([string]$Event,$Fields) { $item=[ordered]@{timestamp=Now;event=$Event};foreach($key in $Fields.Keys){$value=$Fields[$key];$item[$key]=if($value -is [string]){Redact $value}else{$value}};Add-Content (Join-Path $Logs 'bridge.jsonl') ($item|ConvertTo-Json -Compress -Depth 12) -Encoding UTF8 }
function Config { $path=Join-Path $Root 'config.json';if(!(Test-Path $path)){$path=Join-Path $Root 'config.example.json'};Get-Content -Raw $path|ConvertFrom-Json }
function Resolve-CodexExecutable {
  $config=Config;$found=$env:CODEX_EXECUTABLE
  if(!$found){$found=$config.codex_executable}
  if(!$found){$cmd=Get-Command codex -ErrorAction SilentlyContinue;if($cmd){$found=$cmd.Source}}
  if(!$found){$candidate=Get-ChildItem "${env:ProgramFiles}\WindowsApps\OpenAI.Codex_*\app\resources\codex.exe" -ErrorAction SilentlyContinue|Sort-Object FullName -Descending|Select-Object -First 1;if($candidate){$found=$candidate.FullName}}
  if(!$found){throw 'Codex CLI not found'}
  if($found -notmatch 'WindowsApps'){return $found}
  $bin=Join-Path $Runtime 'bin';New-Item -ItemType Directory -Force $bin|Out-Null;$source=Split-Path $found
  foreach($name in @('codex.exe','codex-code-mode-host.exe','codex-command-runner.exe','codex-windows-sandbox-setup.exe')){$from=Join-Path $source $name;$to=Join-Path $bin $name;if(Test-Path $from){if(!(Test-Path $to) -or (Get-Item $to).Length -ne (Get-Item $from).Length){Copy-Item $from $to -Force}}}
  Join-Path $bin 'codex.exe'
}
function Enqueue {
  if(!$TaskId -or !$Instruction){throw 'TaskId and Instruction required'}
  $path=PathOf $TaskId
  if(Test-Path $path){$old=Get-Content -Raw $path|ConvertFrom-Json;Log 'duplicate_rejected' @{task_id=$TaskId;status=$old.status};return [ordered]@{accepted=$false;duplicate=$true;task=$old}}
  $task=[ordered]@{task_id=$TaskId;created_at=Now;instruction=$Instruction;workspace=$Workspace;status='queued';started_at=$null;finished_at=$null;result=$null;error=$null;details=@();files_changed=@();tests=@();warnings=@();commit_id='';codex_session_id=$null;retryable=$null;human_action_required=$null;attempt_count=0}
  WriteJ $task $path;Log 'task_received' @{task_id=$TaskId;instruction=$Instruction};[ordered]@{accepted=$true;duplicate=$false;task=$task}
}
function Execute([string]$Text,[string]$WorkspaceOverride) {
  $config=Config;$exe=Resolve-CodexExecutable;$workspace=$config.workspace
  if(![IO.Path]::IsPathRooted($workspace)){$workspace=Join-Path $Root $workspace}
  if($WorkspaceOverride){
    $workspace=[IO.Path]::GetFullPath($WorkspaceOverride)
    $allowedRoot=[IO.Path]::GetFullPath((Join-Path $env:USERPROFILE 'Documents\GitHub')).TrimEnd('\')+'\'
    if(!$workspace.StartsWith($allowedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Project workspace is outside the approved GitHub root'}
    if(!(Test-Path (Join-Path $workspace '.git'))){throw 'Project workspace is not a Git worktree'}
  }
  New-Item -ItemType Directory -Force $workspace|Out-Null
  $output=Join-Path $Runtime 'last.json';$events=Join-Path $Runtime 'events.jsonl';$errors=Join-Path $Runtime 'stderr.txt';Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue
  $arguments=@('exec','--json','--color','never','--approve-for-me','--cd',$workspace,'--output-schema',(Join-Path $Root 'result.schema.json'),'--output-last-message',$output)
  foreach($directory in $config.allowed_write_directories){$arguments+=@('--add-dir',[IO.Path]::GetFullPath($directory))}
  $prompt="Perform only the requested safe local task. Never modify unrelated files, credentials, system settings, remotes, or main. Verify completion. Return schema JSON with evidence. Use failed when impossible.`nTASK:`n$Text"
  $input=Join-Path $Runtime 'prompt.txt';[IO.File]::WriteAllText($input,$prompt,[Text.UTF8Encoding]::new($false));$arguments+='-'
  $pathValue=$env:PATH;Remove-Item Env:PATH -ErrorAction SilentlyContinue;$env:Path=$pathValue
  $process=Start-Process -FilePath $exe -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardInput $input -RedirectStandardOutput $events -RedirectStandardError $errors
  $timeout=[Math]::Max(1,[int]$config.timeout_seconds)*1000
  if(!$process.WaitForExit($timeout)){$process.Kill();$process.WaitForExit();return [ordered]@{status='failed';result='';error='Codex execution timed out';details=@();files_changed=@();tests=@();warnings=@();commit_id='';retryable=$true;human_action_required=$false;session=$null;code=124}}
  $exitCode=$process.ExitCode
  $session=$null;Get-Content $events -ErrorAction SilentlyContinue|ForEach-Object{try{$event=$_|ConvertFrom-Json;if($event.thread_id){$session=$event.thread_id}elseif($event.session_id){$session=$event.session_id}}catch{}}
  if($exitCode -ne 0 -and !(Test-Path $output)){return [ordered]@{status='failed';result='';error=Redact(Get-Content -Raw $errors);details=@();files_changed=@();tests=@();warnings=@();commit_id='';retryable=$true;human_action_required=$false;session=$session;code=$exitCode}}
  try{$value=Get-Content -Raw $output|ConvertFrom-Json;if($value.status -notin @('success','failed')){throw 'invalid status'};return [ordered]@{status=$value.status;result=$value.result;error=$value.error;details=@($value.details);files_changed=@($value.files_changed);tests=@($value.tests);warnings=@($value.warnings);commit_id=$value.commit_id;retryable=[bool]$value.retryable;human_action_required=[bool]$value.human_action_required;session=$session;code=0}}catch{return [ordered]@{status='failed';result='';error="Could not parse Codex result: $($_.Exception.Message)";details=@();files_changed=@();tests=@();warnings=@();commit_id='';retryable=$true;human_action_required=$false;session=$session;code=$exitCode}}
}
function Run {
  $lock=Join-Path $Queue '.worker.lock';try{$stream=[IO.File]::Open($lock,'CreateNew','Write','None')}catch{throw 'Another worker is running'}
  try{$file=Get-ChildItem $Queue -Filter '*.json'|Sort-Object CreationTime|Where-Object{(Get-Content -Raw -LiteralPath $_.FullName|ConvertFrom-Json).status -eq 'queued'}|Select-Object -First 1;if(!$file){return $null};$task=Get-Content -Raw $file.FullName|ConvertFrom-Json;$task.status='running';$task.started_at=Now;$task.attempt_count++;WriteJ $task $file.FullName;Log 'task_started' @{task_id=$task.task_id;instruction=$task.instruction};$outcome=Execute $task.instruction $task.workspace;$task.status=$outcome.status;$task.finished_at=Now;$task.result=Redact $outcome.result;$task.error=Redact $outcome.error;$task.details=$outcome.details;$task.files_changed=$outcome.files_changed;$task.tests=$outcome.tests;$task.warnings=$outcome.warnings;$task.commit_id=$outcome.commit_id;$task.codex_session_id=$outcome.session;$task.retryable=$outcome.retryable;$task.human_action_required=$outcome.human_action_required;WriteJ $task $file.FullName;WriteJ $task (Join-Path $Results ((Safe $task.task_id)+'.json'));Log 'task_finished' @{task_id=$task.task_id;status=$task.status;result=$task.result;error=$task.error;codex_session_id=$task.codex_session_id};$task}finally{$stream.Dispose();Remove-Item $lock -Force}
}
if($Command -eq 'enqueue'){$value=Enqueue}elseif($Command -eq 'run-once'){$value=Run}elseif($Command -eq 'show'){$path=PathOf $TaskId;if(Test-Path $path){$value=Get-Content -Raw $path|ConvertFrom-Json}}else{$exe=Resolve-CodexExecutable;$value=[ordered]@{executable=$exe;version=((& $exe --version)-join'')}}
$value|ConvertTo-Json -Depth 12
