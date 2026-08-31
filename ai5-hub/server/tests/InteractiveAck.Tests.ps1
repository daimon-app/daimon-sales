$ErrorActionPreference='Stop'
$app=Split-Path (Split-Path $PSScriptRoot)
$source=Get-Content -Raw -Encoding UTF8 (Join-Path $app 'app.js')
if($source-notmatch 'storedTaskProject\|\|"ai5-hub"'){throw 'empty stored Project does not recover to canonical ai5-hub'}
if($source-notmatch "canonical=state\.projects\.find\(p=>p\.projectId==='ai5-hub'\)"){throw 'missing registered canonical Project recovery'}
if($source-notmatch "state\.poll=setInterval\(\(\)=>refreshTask\(id\),2500\)"){throw 'active Task progress poll missing'}
if($source-notmatch "refreshLineChat\(\).*5000"){throw 'durable Result/LINE CHAT poll missing'}
if($source-notmatch '了解。Zero Safety Layerを通して'){throw 'immediate submit ACK missing'}
'INTERACTIVE_ACK_TESTS_PASS'
