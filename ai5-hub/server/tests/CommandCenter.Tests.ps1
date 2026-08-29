$ErrorActionPreference='Stop';$root=Split-Path (Split-Path $PSScriptRoot)
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $root 'server\router\Router.ps1'))))
$direct=Get-AI5Route '現在のGit statusを確認して' 'codex'
if($direct.primary-ne'codex'-or$direct.routingMode-ne'direct_via_zero'-or$direct.requestedTarget-ne'codex'){throw 'direct Codex route failed'}
$claude=Get-AI5Route 'この設計を確認して' 'claude'
if($claude.primary-ne'claude'-or$claude.routingMode-ne'direct_via_zero'){throw 'direct Claude route failed'}
$danger=Get-AI5Route '本番公開して' 'manus'
if(!$danger.requiresApproval-or$danger.primary-ne'manus'){throw 'direct target bypassed Zero safety'}
try{$null=Get-AI5Route 'test' 'invalid';throw 'invalid target accepted'}catch{if($_.Exception.Message-ne'invalid_target'){throw}}
$html=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'index.html');$app=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app.js')
foreach($required in @('AI5 現在の作業','ai5SiblingCards','knowledgeCard','currentWork','profitSummary','targetSelect','AUTO / Zero','各AIの接続と鮮度','書き込み担当','chatFilters','historyFilter','AI5 ${commandMeta(id).name}','コーデックス','クロード','ジェミニ','マナス','鉄兵の確認が必要')){if(($html+$app)-notmatch[regex]::Escape($required)){throw "command center missing: $required"}}
foreach($target in @('codex','claude','gemini','manus','notebooklm','all')){if($html-notmatch('value="'+$target+'"')){throw "target missing: $target"}}
$all=Get-AI5Route '全員で確認して' 'all';if($all.primary-ne'codex'-or@($all.secondary).Count-ne4){throw 'ALL specialist decomposition failed'}
'COMMAND_CENTER_TESTS_OK'
