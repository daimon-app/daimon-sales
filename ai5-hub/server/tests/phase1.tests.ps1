$ErrorActionPreference='Stop'
$root=if($global:AI5TestRoot){$global:AI5TestRoot}else{$PSScriptRoot}
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $root '..\router\Router.ps1'))))
$code=Get-AI5Route 'コードを修正してテスト'
if($code.primary-ne'claude'-or$code.writer-ne'claude'-or$code.requiresApproval){throw 'v6 code route failed'}
$critical=Get-AI5Route 'P0の複雑なCI build障害を修正'
if($critical.primary-ne'codex'-or$critical.secondary-notcontains'claude'){throw 'reserved Codex route failed'}
$research=Get-AI5Route 'Googleの最新市場と競合を調査'
if($research.primary-ne'gemini'){throw 'research route failed'}
$sales=Get-AI5Route 'LPと販売FAQを準備'
if($sales.primary-ne'manus'-or$sales.secondary-notcontains'claude'){throw 'sales route failed'}
$review=Get-AI5Route 'この設計を厳密に監査'
if($review.primary-ne'claude'){throw 'review route failed'}
foreach($danger in @('本番公開する','mainへmerge','Google Play publish','OAuthを承認','2FAを入力','CAPTCHAを通す','広告出稿','SNS公開投稿','DM送信','販売開始','deploy to production','git push --force')){if(!(Get-AI5Route $danger).requiresApproval){throw "approval route failed: $danger"}}
'PHASE1_UNIT_TESTS_OK'
