$ErrorActionPreference='Stop'
$server=Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'repository-lock\RepositoryLock.ps1'))))
$repo=Resolve-Path (Join-Path $PSScriptRoot '..\..\..');$runtime=Join-Path ([IO.Path]::GetTempPath()) ('ai5-lock-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force $runtime|Out-Null
try{$branch=& git -C $repo branch --show-current;$head=& git -C $repo rev-parse HEAD;$first=Enter-AI5RepositoryLock $runtime 'task-one' $repo $branch 'codex' $head;$blocked=$false;try{Enter-AI5RepositoryLock $runtime 'task-two' $repo $branch 'claude' $head|Out-Null}catch{$blocked=$true};if(!$blocked){throw 'same repo branch accepted second writer'};Exit-AI5RepositoryLock $first}finally{Remove-Item -LiteralPath $runtime -Recurse -Force -ErrorAction SilentlyContinue}
'REPOSITORY_WRITER_LOCK_TESTS_OK'
