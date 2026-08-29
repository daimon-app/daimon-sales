$ErrorActionPreference='Stop'
$script:MockMode=$true
$script:claudeHealth=[ordered]@{available=$true;connection='official_cli';quota='20%';checked_at=[DateTime]::UtcNow.ToString('o')}
$script:geminiHealth=[ordered]@{available=$true;connection='chrome';quota='unknown';checked_at=[DateTime]::UtcNow.ToString('o')}
$script:manusHealth=[ordered]@{available=$true;connection='chrome';quota='9%';checked_at=[DateTime]::UtcNow.ToString('o')}
function Get-AI5CodexHealth {[ordered]@{available=$true;connection='official_cli'}}
function Get-AI5ClaudeHealth {$script:claudeHealth}
function Get-AI5SpecialistHealth($Agent){$script:geminiHealth}
function Get-AI5ManusHealth {$script:manusHealth}
function Add-AI5LineMessage {param($Task,$Agent,$State,$Text,$Kind,$Meta);$Task.line_messages+=,[ordered]@{agent=$Agent;state=$State;text=$Text;kind=$Kind}}
. (Join-Path $PSScriptRoot '..\orchestrator\ResourceCommander.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('ai5-resource-'+[guid]::NewGuid().ToString('N'))
try{
  Initialize-AI5ResourceCommander $root
  $credits=Get-AI5CreditRegistry
  if($credits.claude.state-ne'SAVE_MODE'-or$credits.claude.remainingPercent-ne20){throw'Claude SAVE MODE failed'}
  if($credits.manus.state-ne'CRITICAL'-or$credits.manus.remainingPercent-ne9){throw'Manus CRITICAL failed'}
  if($credits.gemini.state-ne'UNKNOWN'-or$null-ne$credits.gemini.remainingPercent){throw'unknown quota was guessed'}
  $task=[pscustomobject]@{taskId='resource-1';assignedPrimary='manus';assigned_agent='manus';assignedSecondary=@();priority='normal';message='大量調査';route=[pscustomobject]@{primary='manus';workType='web_operation'};line_messages=@()}
  $resolved=Resolve-AI5ResourceAssignment $task
  if($resolved.assignedPrimary-ne'gemini'-or!$resolved.resourceDecision.fallbackUsed){throw'Manus fallback failed'}
  $script:claudeHealth=[ordered]@{available=$false;connection='rate_limited';quota='limit reached';checked_at=[DateTime]::UtcNow.ToString('o')}
  if((Get-AI5CreditRegistry).claude.state-ne'EXHAUSTED'){throw'Claude exhausted detection failed'}
  'RESOURCE_COMMANDER_TESTS_PASS'
}finally{Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue}
