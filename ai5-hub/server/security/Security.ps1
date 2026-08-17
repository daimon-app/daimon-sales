function Test-AI5LocalRequest {param($Request);$remote=$Request.RemoteEndPoint.Address.ToString();$remote -in @('127.0.0.1','::1')}
function Test-AI5Csrf {param($Request,[string]$Token);$Request.HttpMethod -eq 'GET' -or $Request.Headers['X-AI5-CSRF'] -eq $Token}
function Test-AI5Instruction {param([string]$Message);if([string]::IsNullOrWhiteSpace($Message)){return 'message is required'};if($Message.Length -gt 4000){return 'message is too long'};$null}

