$ErrorActionPreference='Stop';$root=if($global:AI5TestRoot){$global:AI5TestRoot}else{$PSScriptRoot};$router=Get-Content -Raw -Encoding UTF8 (Join-Path $root '..\router\Router.ps1');. ([ScriptBlock]::Create($router))
$code=Get-AI5Route 'コードを修正してテスト';if($code.primary-ne'codex'-or$code.requiresApproval){throw'code route failed'}
$research=Get-AI5Route 'Googleの最新仕様を調査';if($research.primary-ne'gemini'){throw'research route failed'}
$review=Get-AI5Route 'この設計を厳密に監査';if($review.primary-ne'claude'){throw'review route failed'}
$danger=Get-AI5Route '本番公開して購入する';if(!$danger.requiresApproval-or$danger.risk-ne'high'){throw'approval route failed'}
$manusAddress=Get-AI5Route 'Manus、MANUS_IPHONE_E2E_OK をそのまま返して。read-only疎通確認です。';if($manusAddress.primary-ne'manus'-or$manusAddress.automaticPrimary-ne'manus'){throw'explicit Manus address route failed'}
'PHASE1_UNIT_TESTS_OK'
