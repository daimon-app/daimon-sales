$ErrorActionPreference = 'Stop'
$server = Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'approval\CapabilityPolicy.ps1'))))

function Assert-Equal($Actual, $Expected, [string]$Label) {
    if ($Actual -ne $Expected) { throw "$Label expected=[$Expected] actual=[$Actual]" }
}

$gates = @(
    'payment','purchase','contract','ads','oauth','2fa','captcha','identity',
    'sns_publish','dm_send','main_merge','production_publish','google_play_publish',
    'sale_start','irreversible','secret_external_send','account_create'
)
foreach ($gate in $gates) {
    $result = Test-AI5CapabilityPolicy ([pscustomobject]@{ operation=$gate; message='safe text' })
    Assert-Equal $result.decision 'APPROVAL_REQUIRED' "typed $gate"
    Assert-Equal $result.capability $gate "typed capability $gate"
    Assert-Equal $result.source 'typed_operation' "typed source $gate"
}

$safe = Test-AI5CapabilityPolicy ([pscustomobject]@{ operation='read_only'; message='購入と契約の資料を読む' })
Assert-Equal $safe.decision 'ALLOW' 'typed read-only takes precedence'
Assert-Equal $safe.source 'typed_operation' 'typed precedence source'

$unknownTyped = Test-AI5CapabilityPolicy ([pscustomobject]@{ operation='format_report'; message='販売開始' })
Assert-Equal $unknownTyped.decision 'DENY' 'unknown typed operation denied'

$aliases = [ordered]@{
    '課金'='payment'; '購入'='purchase'; '有料契約'='contract'; '広告出稿'='ads'
    'OAuth認証'='oauth'; '二段階認証'='2fa'; 'CAPTCHA'='captcha'; '本人確認'='identity'
    'SNS公開投稿'='sns_publish'; 'DM送信'='dm_send'; 'mainへmerge'='main_merge'
    '本番公開'='production_publish'; 'Google Play公開'='google_play_publish'; '販売開始'='sale_start'
    '不可逆操作'='irreversible'; '秘密情報外部送信'='secret_external_send'; 'アカウント作成'='account_create'
}
foreach ($entry in $aliases.GetEnumerator()) {
    $result = Test-AI5CapabilityPolicy ([pscustomobject]@{ operation=$entry.Key })
    Assert-Equal $result.capability $entry.Value "alias $($entry.Key)"
}

$fallback = Test-AI5CapabilityPolicy ([pscustomobject]@{ objective='Google Playへ公開する' })
Assert-Equal $fallback.capability 'google_play_publish' 'text fallback'
Assert-Equal $fallback.source 'text_fallback' 'fallback source'

$plainRead = Test-AI5CapabilityPolicy ([pscustomobject]@{ objective='READMEとgit statusを確認する' })
Assert-Equal $plainRead.decision 'ALLOW' 'plain read-only'

'CAPABILITY_POLICY_TESTS_OK'
