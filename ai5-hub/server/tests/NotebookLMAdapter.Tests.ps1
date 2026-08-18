$ErrorActionPreference='Stop';$server=Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'adapters\NotebookLMAdapter.ps1'))))
$request=New-AI5NotebookLMRequest 'task_notebook_test' '過去の承認ルール' ''
if($request.mode-ne'read_only'-or!$request.requireSources){throw'read-only request failed'}
$ok=[ordered]@{status='completed';sources=@('source-1');requiresGithubVerification=$true}
if(!(Test-AI5NotebookLMResult $ok)){throw'valid result rejected'}
$bad=[ordered]@{status='completed';sources=@();requiresGithubVerification=$true}
if(Test-AI5NotebookLMResult $bad){throw'unsourced result accepted'}
'NOTEBOOKLM_ADAPTER_TESTS_OK'
