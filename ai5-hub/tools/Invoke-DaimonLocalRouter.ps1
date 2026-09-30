<#
DAIMON Tool Executor: LOCAL_ROUTER
Exact allowed operation : run the configured local GGUF model (llama.cpp CLI) against one Task
                          and return a routing decision matching DAIMON_WORKER_ROUTING_SPEC.md Section 10.
Input schema            : -TaskPath <file>  (JSON: task_id, objective, task_class_hint?, worker_states?)
                          -ConfigPath <file> (default: local-router.config.json next to this script)
Path/scope restriction  : reads only the given TaskPath/ConfigPath and the model/runtime paths named
                          inside ConfigPath; writes only under <bus_root>\results and <bus_root>\receipts.
Timeout                 : 180s wall clock for the model subprocess (configurable via -TimeoutSeconds).
Exit codes              : 0 = decision produced (may be ESCALATE=true); 1 = bad input; 2 = runtime/model missing.
Result/Receipt/Evidence : writes <bus_root>\results\<task_id>-v1.json,
                          <bus_root>\receipts\<task_id>.json,
                          <bus_root>\results\<task_id>-v1.raw.log (raw model stdout, for audit).
#>
param(
  [Parameter(Mandatory=$true)][string]$TaskPath,
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'local-router.config.json'),
  [int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'

function Write-DecisionAndExit {
  param([hashtable]$Decision, [string]$BusRoot, [string]$RawOutput, [int]$ExitCode)
  $resultDir = Join-Path $BusRoot 'results'
  $receiptDir = Join-Path $BusRoot 'receipts'
  New-Item -ItemType Directory -Force -Path $resultDir,$receiptDir | Out-Null
  $taskId = [string]$Decision.TASK_ID
  $resultPath = Join-Path $resultDir "$taskId-v1.json"
  $rawPath = Join-Path $resultDir "$taskId-v1.raw.log"
  $receiptPath = Join-Path $receiptDir "$taskId.json"
  $now = [DateTimeOffset]::Now.ToString('o')

  $decisionJson = ($Decision | ConvertTo-Json -Depth 10)
  $decisionJson | Set-Content -LiteralPath $resultPath -Encoding utf8
  if ($RawOutput) { $RawOutput | Set-Content -LiteralPath $rawPath -Encoding utf8 }
  $sha256 = [Security.Cryptography.SHA256]::Create()
  $hashBytes = $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($decisionJson))
  $hash = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
  [ordered]@{
    schema_version = '1.0'; task_id = $taskId; result_hash = $hash
    worker = 'FUJITSU_LOCAL_ROUTER'; status = 'COMPLETED'; receipt_at = $now
  } | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding utf8

  $decisionJson | Write-Output
  exit $ExitCode
}

if (!(Test-Path -LiteralPath $TaskPath -PathType Leaf)) {
  Write-Error "TASK_NOT_FOUND: $TaskPath"; exit 1
}
if (!(Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
  Write-Error "CONFIG_NOT_FOUND: $ConfigPath"; exit 1
}
$task = Get-Content -Raw -Encoding utf8 -LiteralPath $TaskPath | ConvertFrom-Json
$config = Get-Content -Raw -Encoding utf8 -LiteralPath $ConfigPath | ConvertFrom-Json
$taskId = [string]$task.task_id
if ([string]::IsNullOrWhiteSpace($taskId)) { Write-Error 'TASK_MISSING_task_id'; exit 1 }
$busRoot = [string]$config.bus_root

# fallback decision used whenever LOCAL_ROUTER cannot produce a trustworthy structured answer.
# Per DAIMON_WORKER_ROUTING_SPEC.md Section 9/13: never guess silently, escalate instead.
function New-FallbackDecision([string]$Reason) {
  @{
    TASK_ID = $taskId; TASK_CLASS = 'UNKNOWN'; TASK_COMPLEXITY = 'UNKNOWN'
    SELECTED_NODE = 'FUJITSU'; PRIMARY_WORKER = 'FUJITSU_CLAUDE'; REVIEWER = $null
    FALLBACK_WORKER = $null; CONFIDENCE = 'LOW'; REASON = $Reason
    RESOURCE_STATE = 'UNKNOWN'; QUOTA_POLICY = 'UNKNOWN'; RECOVERY_RUNBOOK = $null
    ESCALATE = $true
  }
}

if (!(Test-Path -LiteralPath ([string]$config.runtime_binary) -PathType Leaf) -or
    !(Test-Path -LiteralPath ([string]$config.model_path) -PathType Leaf)) {
  Write-DecisionAndExit -Decision (New-FallbackDecision 'LOCAL_ROUTER runtime or model file missing; see DAIMON_TOOL_EXECUTOR fallback rule (spec Section 13).') -BusRoot $busRoot -RawOutput $null -ExitCode 2
}

$schemaHint = 'Return ONLY one JSON object, single line, with exactly these keys: TASK_ID, TASK_CLASS, TASK_COMPLEXITY, SELECTED_NODE, PRIMARY_WORKER, REVIEWER, FALLBACK_WORKER, CONFIDENCE, REASON, RESOURCE_STATE, QUOTA_POLICY, RECOVERY_RUNBOOK, ESCALATE. SELECTED_NODE must be a NODE identifier only (e.g. FUJITSU or DYNABOOK), never a Worker identifier. PRIMARY_WORKER/REVIEWER/FALLBACK_WORKER must be Worker identifiers in NODE_WORKERNAME form (e.g. FUJITSU_CLAUDE, DYNABOOK_CODEX, FUJITSU_LOCAL_ROUTER). If the task is classification, summarization, a small structured transform, or light diagnostics with testable acceptance criteria, prefer PRIMARY_WORKER=FUJITSU_LOCAL_ROUTER (yourself) over a cloud worker - do not spend a stronger worker on something you can do yourself. REVIEWER must be a DIFFERENT worker than PRIMARY_WORKER whenever an independent worker with adequate health is available (builder != reviewer); only set REVIEWER equal to PRIMARY_WORKER or null if truly no independent worker exists. Before naming ANY worker in ANY role (PRIMARY_WORKER, REVIEWER, or FALLBACK_WORKER), check that worker''s own LIMIT_STATE/health in the TASK data - never name a worker whose LIMIT_STATE is EXHAUSTED or health is unavailable in any of the three role fields, including FALLBACK_WORKER. CONFIDENCE must be HIGH, MEDIUM, or LOW. ESCALATE must be true or false (boolean). If unsure, set CONFIDENCE to LOW and ESCALATE to true rather than guessing. Do not add prose before or after the JSON.'
$taskJsonCompact = ($task | ConvertTo-Json -Depth 10 -Compress)
$prompt = "You are FUJITSU_LOCAL_ROUTER, the Level 1 deterministic-assist router for a DAIMON Node. $schemaHint TASK: $taskJsonCompact"

# Start-Process -ArgumentList does NOT auto-quote array elements containing spaces
# (unlike the `&` call operator) - it naively joins with spaces, which breaks any
# argument containing whitespace (the prompt, here). Build one pre-quoted string instead,
# escaping embedded double-quotes per Win32 CommandLineToArgvW rules (" -> \").
function ConvertTo-WinArg([string]$Value) {
  '"' + ($Value -replace '"', '\"') + '"'
}
$argString = @(
  '-m', (ConvertTo-WinArg ([string]$config.model_path)),
  '-p', (ConvertTo-WinArg $prompt),
  '-n', [string]$config.n_predict,
  '--temp', [string]$config.temperature,
  '-st',
  '-t', [string]$config.threads
) -join ' '

$stdoutFile = [IO.Path]::GetTempFileName()
$stderrFile = [IO.Path]::GetTempFileName()
try {
  $proc = Start-Process -FilePath ([string]$config.runtime_binary) `
    -ArgumentList $argString `
    -NoNewWindow -PassThru -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile

  $finished = $proc.WaitForExit($TimeoutSeconds * 1000)
  if (-not $finished) {
    try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    $raw = (Get-Content -Raw -Encoding utf8 -LiteralPath $stdoutFile -ErrorAction SilentlyContinue)
    Write-DecisionAndExit -Decision (New-FallbackDecision "LOCAL_ROUTER timed out after ${TimeoutSeconds}s; escalating per spec Section 13.") -BusRoot $busRoot -RawOutput $raw -ExitCode 0
  }
  $raw = Get-Content -Raw -Encoding utf8 -LiteralPath $stdoutFile -ErrorAction SilentlyContinue
  $rawErr = Get-Content -Raw -Encoding utf8 -LiteralPath $stderrFile -ErrorAction SilentlyContinue
} finally {
  Remove-Item -LiteralPath $stdoutFile,$stderrFile -ErrorAction SilentlyContinue
}
if ([string]::IsNullOrEmpty($raw)) {
  Write-DecisionAndExit -Decision (New-FallbackDecision "LOCAL_ROUTER produced no stdout (exit=$($proc.ExitCode)); stderr: $rawErr; escalating.") -BusRoot $busRoot -RawOutput $rawErr -ExitCode 0
}

# Extract the model's answer: the line(s) after the echoed "> <prompt>" marker, before the "[ Prompt:" stats footer.
$afterPrompt = $raw
$echoIdx = $raw.IndexOf("> $prompt")
if ($echoIdx -ge 0) { $afterPrompt = $raw.Substring($echoIdx + ("> $prompt").Length) }
$statsIdx = $afterPrompt.IndexOf('[ Prompt:')
if ($statsIdx -ge 0) { $afterPrompt = $afterPrompt.Substring(0, $statsIdx) }
$afterPrompt = $afterPrompt.Trim()

$jsonStart = $afterPrompt.IndexOf('{')
$jsonEnd = $afterPrompt.LastIndexOf('}')
if ($jsonStart -lt 0 -or $jsonEnd -le $jsonStart) {
  Write-DecisionAndExit -Decision (New-FallbackDecision 'LOCAL_ROUTER did not return a parseable JSON object; escalating per spec Section 9 (no silent guessing).') -BusRoot $busRoot -RawOutput $raw -ExitCode 0
}
$candidate = $afterPrompt.Substring($jsonStart, $jsonEnd - $jsonStart + 1)

try {
  $parsed = $candidate | ConvertFrom-Json
} catch {
  Write-DecisionAndExit -Decision (New-FallbackDecision "LOCAL_ROUTER JSON failed to parse: $($_.Exception.Message); escalating.") -BusRoot $busRoot -RawOutput $raw -ExitCode 0
}

$requiredFields = @('TASK_ID','TASK_CLASS','TASK_COMPLEXITY','SELECTED_NODE','PRIMARY_WORKER','REVIEWER','FALLBACK_WORKER','CONFIDENCE','REASON','RESOURCE_STATE','QUOTA_POLICY','RECOVERY_RUNBOOK','ESCALATE')
$missing = @($requiredFields | Where-Object { -not ($parsed.PSObject.Properties.Name -contains $_) })
if ($missing.Count) {
  Write-DecisionAndExit -Decision (New-FallbackDecision "LOCAL_ROUTER output missing required fields: $($missing -join ', '); escalating (strict schema, spec Section 10).") -BusRoot $busRoot -RawOutput $raw -ExitCode 0
}

$decision = @{}
foreach ($f in $requiredFields) { $decision[$f] = $parsed.$f }
if ([string]$decision.TASK_ID -ne $taskId) { $decision.TASK_ID = $taskId }

Write-DecisionAndExit -Decision $decision -BusRoot $busRoot -RawOutput $raw -ExitCode 0
