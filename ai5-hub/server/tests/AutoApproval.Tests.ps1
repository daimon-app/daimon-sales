$ErrorActionPreference='Stop'
$server=Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'router\Router.ps1'))))
function Assert-Auto($ok,$message){if(!$ok){throw $message}}
$code=Get-AI5Route '通常コードを修正してtest build commitまで行う';Assert-Auto (!$code.requiresApproval-and$code.approvalClass-eq'TECHNICAL_AUTO') 'TEST-01 technical auto failed'
$build=Get-AI5Route 'build failureを解析し修正して再テスト';Assert-Auto (!$build.requiresApproval) 'TEST-02 build failure incorrectly gated'
$money=Get-AI5Route '500円の課金操作を確定する';Assert-Auto ($money.approvalClass-eq'OWNER_MONEY'-and$money.requiresApproval) 'TEST-03 money gate failed'
$publish=Get-AI5Route 'Google Play一般公開を実行する';Assert-Auto ($publish.approvalClass-eq'OWNER_PUBLISH') 'TEST-04 publish gate failed'
$identity=Get-AI5Route 'CAPTCHAと2FAを完了する';Assert-Auto ($identity.approvalClass-eq'OWNER_IDENTITY') 'TEST-05 identity gate failed'
$delete=Get-AI5Route 'Repository大量削除を実行する';Assert-Auto ($delete.approvalClass-eq'OWNER_IRREVERSIBLE'-and$delete.riskEvaluation.destructive) 'TEST-06 irreversible gate failed'
$review=Get-AI5Route '技術変更を別AIで監査してPASSなら続行';Assert-Auto (!$review.requiresApproval) 'TEST-07 verifier pass route failed'
$repair=Get-AI5Route '独立監査FAILなら原因解析して自動修正ループ';Assert-Auto (!$repair.requiresApproval) 'TEST-08 repair loop route failed'
$source=Get-Content -Raw -Encoding UTF8 (Join-Path $server 'server.ps1');Assert-Auto ($source-match'OWNER_APPROVED_AUTO_RESUME'-and$source-match'Dispatch-Task \$task') 'TEST-09 auto resume missing'
$push=Get-Content -Raw -Encoding UTF8 (Join-Path $server 'notifications\PushNotification.ps1');$sw=Get-Content -Raw -Encoding UTF8 (Join-Path (Split-Path $server) 'service-worker.js');Assert-Auto ($push-match'\?approval='-and$sw-match'notificationclick'-and$push-match'OWNER_MONEY') 'TEST-10 notification/deep link failed'
'AUTO_APPROVAL_TESTS_10_OK'
