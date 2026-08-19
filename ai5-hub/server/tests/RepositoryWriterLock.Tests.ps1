$ErrorActionPreference='Stop'
$server=Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'repository-lock\RepositoryLock.ps1'))))
$repo=Join-Path ([IO.Path]::GetTempPath()) ('ai5-repo-'+[guid]::NewGuid().ToString('N'));$runtime=Join-Path ([IO.Path]::GetTempPath()) ('ai5-lock-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force $runtime,$repo|Out-Null
function Get-AI5RepositorySnapshot {param([string]$Path);[ordered]@{repository=$true;path=$Path;branch='feature';head='abc123';dirty=$false;status=@();captured_at=[DateTime]::UtcNow.ToString('o')}}
try{$first=Enter-AI5RepositoryLock $runtime 'task-one' $repo 'feature' 'codex' 'abc123';$blocked=$false;try{Enter-AI5RepositoryLock $runtime 'task-two' $repo 'feature' 'claude' 'abc123'|Out-Null}catch{$blocked=$true};if(!$blocked){throw 'same repo branch accepted second writer'};$ownerBlocked=$false;try{Exit-AI5RepositoryLock $first 'task-two'}catch{$ownerBlocked=$true};if(!$ownerBlocked){throw 'non-owner released lock'};Exit-AI5RepositoryLock $first 'task-one'}finally{Remove-Item -LiteralPath $runtime,$repo -Recurse -Force -ErrorAction SilentlyContinue}
'REPOSITORY_WRITER_LOCK_TESTS_OK'
