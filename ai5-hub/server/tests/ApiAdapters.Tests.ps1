$ErrorActionPreference='Stop';$server=Split-Path $PSScriptRoot;. (Join-Path $server 'orchestrator\ClosedLoopCore.ps1');. (Join-Path $server 'adapters\ClaudeApiAdapter.ps1');. (Join-Path $server 'adapters\GeminiApiAdapter.ps1')
$task=[pscustomobject]@{TASK_ID='api-test';CORRELATION_ID='corr-api';PROJECT_ID='ai5-hub';PURPOSE='read only';CANONICAL_REPO='daimon-app/daimon-sales';CANONICAL_BRANCH='main';ALLOWED_ACTIONS=@('READ');PROHIBITED_ACTIONS=@('WRITE');EXPECTED_RESULT=@{status='PASS'}}
$claudeTransport={param($uri,$headers,$payload);if($uri-ne'https://api.anthropic.com/v1/messages'-or!$headers['x-api-key']-or!$headers['anthropic-version']){throw 'bad Claude transport'};[pscustomobject]@{content=@([pscustomobject]@{type='text';text='CLAUDE_API_MOCK_OK'})}}
$geminiTransport={param($uri,$headers,$payload);if($uri-notmatch'generativelanguage.googleapis.com'-or!$headers['x-goog-api-key']){throw 'bad Gemini transport'};[pscustomobject]@{candidates=@([pscustomobject]@{content=[pscustomobject]@{parts=@([pscustomobject]@{text='GEMINI_API_MOCK_OK'})}})}}
$c=Invoke-AI5ClaudeApiAdapter $task $claudeTransport 'test-key';if($c.STATUS-ne'PASS'-or$c.SUMMARY-ne'CLAUDE_API_MOCK_OK'){throw 'Claude API contract failed'}
$g=Invoke-AI5GeminiApiAdapter $task $geminiTransport 'test-key';if($g.STATUS-ne'PASS'-or$g.SUMMARY-ne'GEMINI_API_MOCK_OK'){throw 'Gemini API contract failed'}
$missingC=Invoke-AI5ClaudeApiAdapter $task;if($missingC.STATUS-notin@('WAITING_OWNER_AUTH','PASS')){throw 'Claude missing credential state invalid'}
$missingG=Invoke-AI5GeminiApiAdapter $task;if($missingG.STATUS-notin@('WAITING_OWNER_AUTH','PASS')){throw 'Gemini missing credential state invalid'}
'API_ADAPTER_CONTRACT_TESTS_OK'
