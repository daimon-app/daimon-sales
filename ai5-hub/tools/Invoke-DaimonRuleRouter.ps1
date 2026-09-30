<#
DAIMON Tool Executor: LEVEL 0 Deterministic Rule Router
Exact allowed operation : classify a Task using fixed deterministic rules ONLY (no AI invocation).
                          Falls through to LOCAL_ROUTER (Invoke-DaimonLocalRouter.ps1) only when no
                          rule matches - per DAIMON_WORKER_ROUTING_SPEC.md Section 1 ("simple
                          deterministic routing must not invoke an AI unnecessarily").
Input schema            : -TaskPath <file> (same Task JSON shape as Invoke-DaimonLocalRouter.ps1)
Path/scope restriction  : reads only TaskPath; delegates to Invoke-DaimonLocalRouter.ps1 (same
                          restrictions as that script) only on fallthrough.
Timeout                 : instant for rule matches; inherits LOCAL_ROUTER's timeout on fallthrough.
Exit codes              : 0 = decision produced (rule match or LOCAL_ROUTER fallthrough); 1 = bad input.
Result/Receipt/Evidence : rule-matched decisions are written the same way as LOCAL_ROUTER's, with
                          RECOVERY_RUNBOOK/REASON noting "LEVEL0_RULE_MATCH:<rule name>" so Evidence
                          shows which layer actually decided.
#>
param(
  [Parameter(Mandatory=$true)][string]$TaskPath,
  [string]$ConfigPath = 'C:\Users\teppe\Documents\GitHub\daimon-sales\ai5-hub\tools\local-router.config.json'
)
$ErrorActionPreference = 'Stop'

if (!(Test-Path -LiteralPath $TaskPath -PathType Leaf)) { Write-Error "TASK_NOT_FOUND: $TaskPath"; exit 1 }
$task = Get-Content -Raw -Encoding utf8 -LiteralPath $TaskPath | ConvertFrom-Json
$config = Get-Content -Raw -Encoding utf8 -LiteralPath $ConfigPath | ConvertFrom-Json
$taskId = [string]$task.task_id
$busRoot = [string]$config.bus_root

function Write-RuleDecision([hashtable]$Decision) {
  $resultDir = Join-Path $busRoot 'results'; $receiptDir = Join-Path $busRoot 'receipts'
  New-Item -ItemType Directory -Force -Path $resultDir,$receiptDir | Out-Null
  $json = $Decision | ConvertTo-Json -Depth 10
  $json | Set-Content -LiteralPath (Join-Path $resultDir "$taskId-v1.json") -Encoding utf8
  $sha256 = [Security.Cryptography.SHA256]::Create()
  $hash = -join ($sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($json)) | ForEach-Object { $_.ToString('x2') })
  [ordered]@{ schema_version='1.0'; task_id=$taskId; result_hash=$hash; worker='FUJITSU_RULE_ROUTER'; status='COMPLETED'; receipt_at=[DateTimeOffset]::Now.ToString('o') } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $receiptDir "$taskId.json") -Encoding utf8
  $json | Write-Output
  exit 0
}

# --- deterministic rules, evaluated in order; first match wins ---
$hint = [string]$task.task_class_hint

# Rule: read-only inspection tasks never need AI routing at all - always FUJITSU_CLAUDE, no escalation.
if ($hint -in @('read_only_inspection','diagnostic_read')) {
  Write-RuleDecision @{
    TASK_ID=$taskId; TASK_CLASS=$hint; TASK_COMPLEXITY='LOW'; SELECTED_NODE='FUJITSU'
    PRIMARY_WORKER='FUJITSU_CLAUDE'; REVIEWER=$null; FALLBACK_WORKER=$null
    CONFIDENCE='HIGH'; REASON='LEVEL0_RULE_MATCH:read_only_inspection - no reviewer needed, nothing to break.'
    RESOURCE_STATE='UNKNOWN'; QUOTA_POLICY='UNKNOWN'; RECOVERY_RUNBOOK=$null; ESCALATE=$false
  }
}

# Rule: explicit emergency/heartbeat-loss classes always escalate immediately - Level 0 does not
# attempt classification of an emergency itself (spec Section 8: allowlisted runbooks only).
if ($hint -in @('heartbeat_loss','node_outage','provider_outage')) {
  Write-RuleDecision @{
    TASK_ID=$taskId; TASK_CLASS=$hint; TASK_COMPLEXITY='UNKNOWN'; SELECTED_NODE='FUJITSU'
    PRIMARY_WORKER='FUJITSU_CLAUDE'; REVIEWER=$null; FALLBACK_WORKER=$null
    CONFIDENCE='HIGH'; REASON='LEVEL0_RULE_MATCH:emergency class always escalates per spec Section 8.'
    RESOURCE_STATE='UNKNOWN'; QUOTA_POLICY='UNKNOWN'; RECOVERY_RUNBOOK='PENDING_RUNBOOK_SELECTION'; ESCALATE=$true
  }
}

# No deterministic rule matched -> fall through to LOCAL_ROUTER (Level 1).
$localRouterScript = Join-Path (Split-Path $ConfigPath -Parent) 'Invoke-DaimonLocalRouter.ps1'
& $localRouterScript -TaskPath $TaskPath -ConfigPath $ConfigPath
exit $LASTEXITCODE
