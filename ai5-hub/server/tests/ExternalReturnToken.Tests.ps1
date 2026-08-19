$ErrorActionPreference='Stop'
$server=Split-Path $PSScriptRoot
function Protect-AI5Object($Value){$Value}
function Get-AI5PayloadHash([string]$Value){$sha=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}}
function Save-AI5Task($Task){}
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'adapters\ExternalTaskAdapter.ps1'))))
$root=Join-Path ([IO.Path]::GetTempPath()) ('ai5-external-'+[guid]::NewGuid().ToString('N'))
try{Initialize-AI5ExternalTaskAdapter $root;$task=[pscustomobject]@{task_id='task-token';project_id='p';product_id='m1';objective='audit';support_ai=@();writer='NONE';priority='high';source_commit='abc';expected_output='result';acceptance_criteria=@('one');constraints=@()};$request=Submit-AI5ExternalTask $task 'manus';if(!$request.return_token-or!$task.external_return_token_hash){throw 'return token not created'};if(!(Test-AI5ExternalReturnToken $task $request.return_token)){throw 'valid return token rejected'};if(Test-AI5ExternalReturnToken $task 'wrong'){throw 'invalid return token accepted'}}finally{Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue}
'EXTERNAL_RETURN_TOKEN_TESTS_OK'
