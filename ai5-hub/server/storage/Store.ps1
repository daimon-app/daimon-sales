function Initialize-AI5Store {
  param([string]$ServerRoot)
  $script:DataRoot=Join-Path $ServerRoot 'data'; $script:TaskRoot=Join-Path $script:DataRoot 'tasks'; $script:LogRoot=Join-Path $ServerRoot 'logs'
  @($script:DataRoot,$script:TaskRoot,(Join-Path $script:LogRoot 'tasks'),(Join-Path $script:LogRoot 'security'),(Join-Path $script:LogRoot 'errors'))|ForEach-Object{New-Item -ItemType Directory -Force $_|Out-Null}
}
function Protect-AI5Text([string]$Value){if($null-eq$Value){return $null};$Value -replace '(?i)(api[_-]?key|token|password|secret)\s*[:=]\s*([^\s,;]+)','$1=[REDACTED]'}
function Get-AI5TaskPath([string]$TaskId){Join-Path $script:TaskRoot (($TaskId-replace'[^A-Za-z0-9_.-]','_')+'.json')}
function Save-AI5Task {param($Task);$path=Get-AI5TaskPath $Task.taskId;$temp="$path.tmp";$Task.updatedAt=[DateTime]::UtcNow.ToString('o');$Task|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $temp -Encoding UTF8;Move-Item -LiteralPath $temp -Destination $path -Force}
function Get-AI5Task {param([string]$TaskId);$path=Get-AI5TaskPath $TaskId;if(Test-Path $path){Get-Content -Raw -Encoding UTF8 $path|ConvertFrom-Json}}
function Get-AI5Tasks {param([int]$Limit=100);Get-ChildItem $script:TaskRoot -Filter '*.json' -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First $Limit|ForEach-Object{Get-Content -Raw -Encoding UTF8 $_.FullName|ConvertFrom-Json}}
function Get-AI5NextTaskId {
  $date=(Get-Date).ToString('yyyyMMdd');$counterPath=Join-Path $script:DataRoot "task-counter-$date.txt"
  $stream=[IO.File]::Open($counterPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
  try{$reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8,$true,1024,$true);$raw=$reader.ReadToEnd();$reader.Dispose();$n=0;[int]::TryParse($raw.Trim(),[ref]$n)|Out-Null;$n++;$stream.SetLength(0);$writer=[IO.StreamWriter]::new($stream,[Text.Encoding]::UTF8,1024,$true);$writer.Write($n);$writer.Flush();$writer.Dispose();return ('AI5-{0}-{1:D4}' -f $date,$n)}finally{$stream.Dispose()}
}
function Write-AI5Log {param([string]$Area,[string]$Event,$Fields);$dir=Join-Path $script:LogRoot $Area;New-Item -ItemType Directory -Force $dir|Out-Null;$item=[ordered]@{timestamp=[DateTime]::UtcNow.ToString('o');event=$Event};foreach($key in $Fields.Keys){$value=$Fields[$key];$item[$key]=if($value-is[string]){Protect-AI5Text $value}else{$value}};Add-Content -LiteralPath (Join-Path $dir ((Get-Date).ToString('yyyy-MM-dd')+'.jsonl')) -Encoding UTF8 -Value ($item|ConvertTo-Json -Compress -Depth 8)}
