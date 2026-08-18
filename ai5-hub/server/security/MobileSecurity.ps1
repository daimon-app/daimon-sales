function Initialize-AI5MobileSecurity {
    param([string]$ServerRoot)
    $script:SessionRoot = Join-Path $ServerRoot 'runtime\sessions'
    $script:ApprovalRoot = Join-Path $ServerRoot 'runtime\approvals'
    New-Item -ItemType Directory -Force $script:SessionRoot, $script:ApprovalRoot | Out-Null
    $script:SessionHours = 8
    $script:ApprovalMinutes = 5
}

function New-AI5RandomToken {
    param([int]$Bytes = 32)
    $buffer = New-Object byte[] $Bytes
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($buffer) } finally { $generator.Dispose() }
    return [Convert]::ToBase64String($buffer).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-AI5Hash {
    param([string]$Value)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function ConvertTo-AI5UtcDateTime {param($Value);if($Value-is[DateTime]){return $Value.ToUniversalTime()};return [DateTime]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal)}

function Get-AI5CookieValue {
    param($Request, [string]$Name)
    $cookie = $Request.Headers['Cookie']
    if (!$cookie) { return $null }
    foreach ($part in $cookie.Split(';')) {
        $pair = $part.Trim().Split('=', 2)
        if ($pair.Count -eq 2 -and $pair[0] -eq $Name) { return $pair[1] }
    }
    return $null
}

function Test-AI5LoopbackHost {
    param($Request)
    $hostName = [string]$Request.Headers['Host']
    return $hostName -match '^(127\.0\.0\.1|localhost|\[?::1\]?)(:\d+)?$'
}

function Get-AI5TailscaleIdentity {
    param($Request)
    $login = [string]$Request.Headers['Tailscale-User-Login']
    if ([string]::IsNullOrWhiteSpace($login)) { return $null }
    return [ordered]@{ login = $login; name = [string]$Request.Headers['Tailscale-User-Name'] }
}

function New-AI5Session {
    param($Identity)
    $id = New-AI5RandomToken
    $expires = [DateTime]::UtcNow.AddHours($script:SessionHours)
    $record = [ordered]@{ idHash = Get-AI5Hash $id; login = $Identity.login; name = $Identity.name; createdAt = [DateTime]::UtcNow.ToString('o'); expiresAt = $expires.ToString('o') }
    $path = Join-Path $script:SessionRoot ((Get-AI5Hash $id) + '.json')
    $record | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
    return [ordered]@{ id = $id; record = $record; cookie = "ai5_session=$id; Path=/; Max-Age=$($script:SessionHours * 3600); HttpOnly; Secure; SameSite=Strict" }
}

function Get-AI5Session {
    param($Request)
    if (Test-AI5LoopbackHost $Request) { return [ordered]@{ local = $true; login = 'local-windows'; name = 'Local Windows'; expiresAt = $null } }
    $id = Get-AI5CookieValue $Request 'ai5_session'
    if (!$id) { return $null }
    $path = Join-Path $script:SessionRoot ((Get-AI5Hash $id) + '.json')
    if (!(Test-Path $path)) { return $null }
    $record = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    if ((ConvertTo-AI5UtcDateTime $record.expiresAt) -le [DateTime]::UtcNow) { Remove-Item -LiteralPath $path -Force; return $null }
    $identity = Get-AI5TailscaleIdentity $Request
    if (!$identity -or $identity.login -ne $record.login) { return $null }
    return $record
}

function Remove-AI5Session {
    param($Request)
    $id = Get-AI5CookieValue $Request 'ai5_session'
    if ($id) { Remove-Item -LiteralPath (Join-Path $script:SessionRoot ((Get-AI5Hash $id) + '.json')) -Force -ErrorAction SilentlyContinue }
    return 'ai5_session=deleted; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Strict'
}

function New-AI5ApprovalToken {
    param([string]$TaskId)
    $token = New-AI5RandomToken
    $record = [ordered]@{ taskId = $TaskId; tokenHash = Get-AI5Hash $token; expiresAt = [DateTime]::UtcNow.AddMinutes($script:ApprovalMinutes).ToString('o'); used = $false }
    $record | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:ApprovalRoot ($TaskId + '.json')) -Encoding UTF8
    return $token
}

function Use-AI5ApprovalToken {
    param([string]$TaskId, [string]$Token)
    $path = Join-Path $script:ApprovalRoot ($TaskId + '.json')
    if (!(Test-Path $path) -or !$Token) { return $false }
    $record = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    if ($record.used -or (ConvertTo-AI5UtcDateTime $record.expiresAt) -le [DateTime]::UtcNow -or $record.tokenHash -ne (Get-AI5Hash $Token)) { return $false }
    $record.used = $true
    $record | Add-Member -NotePropertyName usedAt -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
    $record | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
    return $true
}
