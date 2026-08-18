function Test-AI5LocalRequest {param($Request);$remote=$Request.RemoteEndPoint.Address.ToString();$remote -in @('127.0.0.1','::1')}
function Test-AI5Csrf {param($Request,[string]$Token);$Request.HttpMethod -eq 'GET' -or $Request.Headers['X-AI5-CSRF'] -eq $Token}
function Test-AI5Instruction {param([string]$Message,[switch]$Long);if([string]::IsNullOrWhiteSpace($Message)){return 'message is required'};$limit=if($Long){262144}else{4000};if($Message.Length-gt$limit){return $(if($Long){'message_too_large'}else{'long_message_ingestion_required'})};$null}

