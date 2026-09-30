<#
DAIMON Tool Executor: DISPATCH (Task Queue -> Router -> Lease -> Execute -> Result/Receipt)
Exact allowed operation : advance exactly one READY Task through lease acquisition, routing,
                          and (for FUJITSU_LOCAL_ROUTER only) real local execution. Never touches
                          any Task not in READY state (duplicate-execution prevention).
Input schema            : -TaskPath <file> (task_id, objective, task_class_hint, acceptance_criteria[],
                          status). ConfigPath as in the router scripts.
Path/scope restriction  : reads/writes only under <bus_root> (tasks/leases/results/receipts) and the
                          worker-registry.json next to it. Never touches files outside <bus_root>.
Timeout                 : inherits LOCAL_ROUTER's 180s subprocess timeout for any model call.
Exit codes              : 0 = task advanced (any resulting state); 1 = bad input; 2 = already claimed
                          (duplicate-execution guard tripped).
Result/Receipt/Evidence : bus\results\<task_id>-v1.json (routing decision),
                          bus\results\<task_id>-exec.json (execution result, if self-executed),
                          bus\receipts\<task_id>.json, bus\leases\<task_id>.lease.json (released on exit).
#>
param(
  [Parameter(Mandatory=$true)][string]$TaskPath,
  [string]$ConfigPath = 'C:\Users\teppe\Documents\GitHub\daimon-sales\ai5-hub\tools\local-router.config.json'
)
$ErrorActionPreference = 'Stop'

$config = Get-Content -Raw -Encoding utf8 -LiteralPath $ConfigPath | ConvertFrom-Json
$busRoot = [string]$config.bus_root
$toolsDir = Split-Path $ConfigPath -Parent
$registryPath = Join-Path $busRoot 'worker-registry.json'
$leaseDir = Join-Path $busRoot 'leases'
New-Item -ItemType Directory -Force -Path $leaseDir | Out-Null

if (!(Test-Path -LiteralPath $TaskPath -PathType Leaf)) { Write-Error "TASK_NOT_FOUND: $TaskPath"; exit 1 }
$task = Get-Content -Raw -Encoding utf8 -LiteralPath $TaskPath | ConvertFrom-Json
$taskId = [string]$task.task_id
if ([string]::IsNullOrWhiteSpace($taskId)) { Write-Error 'TASK_MISSING_task_id'; exit 1 }

$leasePath = Join-Path $leaseDir "$taskId.lease.json"
$status = [string]$task.status

# --- stale-lease recovery: a hard-killed Worker (session interrupt, crash) skips our `finally`
# block entirely, leaving status=RUNNING/CLAIMED and an orphaned lease forever. Distinguish that
# from a genuinely-active duplicate by checking whether the lease's recorded PID is still alive.
# Real incident this guards against: DAIMON-TEST-010, 2026-09-30, background task killed mid-run.
if ($status -in @('RUNNING','CLAIMED') -and (Test-Path -LiteralPath $leasePath)) {
  $existingLease = $null
  try { $existingLease = Get-Content -Raw -Encoding utf8 -LiteralPath $leasePath | ConvertFrom-Json } catch {}
  $ownerAlive = $false
  if ($existingLease -and $existingLease.pid) {
    $ownerAlive = [bool](Get-Process -Id ([int]$existingLease.pid) -ErrorAction SilentlyContinue)
  }
  if (-not $ownerAlive) {
    Write-Output "STALE_LEASE_RECLAIMED: $taskId was '$status' with a lease held by pid=$($existingLease.pid) which is no longer running. Reclaiming."
    Remove-Item -LiteralPath $leasePath -Force -ErrorAction SilentlyContinue
    $status = 'READY'
  }
}

if ($status -and $status -ne 'READY') {
  Write-Output "SKIP: task $taskId is already '$status', not READY. Duplicate-execution guard tripped."
  exit 2
}

# --- atomic lease acquisition: New-Item fails if the file already exists (duplicate-execution guard) ---
try {
  New-Item -ItemType File -Path $leasePath -ErrorAction Stop | Out-Null
} catch {
  Write-Output "SKIP: lease already held for $taskId ($leasePath exists). Duplicate-execution guard tripped."
  exit 2
}
@{ task_id=$taskId; acquired_at=[DateTimeOffset]::Now.ToString('o'); worker='PENDING_ROUTING'; pid=$PID } |
  ConvertTo-Json | Set-Content -LiteralPath $leasePath -Encoding utf8

function Set-TaskStatus([string]$NewStatus, [hashtable]$Extra) {
  $t = Get-Content -Raw -Encoding utf8 -LiteralPath $TaskPath | ConvertFrom-Json
  $t | Add-Member -Force NoteProperty status $NewStatus
  if ($Extra) { foreach ($k in $Extra.Keys) { $t | Add-Member -Force NoteProperty $k $Extra[$k] } }
  $t | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $TaskPath -Encoding utf8
}

function Set-WorkerState([string]$WorkerId, [hashtable]$Fields) {
  if (!(Test-Path -LiteralPath $registryPath)) { return }
  $reg = Get-Content -Raw -Encoding utf8 -LiteralPath $registryPath | ConvertFrom-Json
  if (-not ($reg.workers.PSObject.Properties.Name -contains $WorkerId)) { return }
  foreach ($k in $Fields.Keys) { $reg.workers.$WorkerId | Add-Member -Force NoteProperty $k $Fields[$k] }
  $reg | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $registryPath -Encoding utf8
}

try {
  Set-TaskStatus 'CLAIMED' $null

  # LEVEL 0 / LEVEL 1 routing (reuses the already-verified rule/local router).
  $ruleRouterScript = Join-Path $toolsDir 'Invoke-DaimonRuleRouter.ps1'
  $decisionJson = & $ruleRouterScript -TaskPath $TaskPath -ConfigPath $ConfigPath
  $decision = $decisionJson | ConvertFrom-Json
  $primaryWorker = [string]$decision.PRIMARY_WORKER

  # HARD CAPABILITY GUARD: FUJITSU_LOCAL_ROUTER is text-generation only (llama-cli, no filesystem/
  # shell access). It must never self-execute a task whose acceptance criteria imply a real side
  # effect (file/config/script creation) - LOCAL_ROUTER previously claimed "hello.txt created" for
  # exactly such a task without creating anything (caught 2026-09-30, DAIMON-TEST-009). Reroute to
  # FUJITSU_CODEX instead, which actually has filesystem execution and is verified post-hoc.
  $sideEffectPattern = 'file|creat|write|config|script|install|deploy'
  $impliesSideEffect = (($task.acceptance_criteria -join ' ') + ' ' + [string]$task.objective) -match $sideEffectPattern
  if ($primaryWorker -eq 'FUJITSU_LOCAL_ROUTER' -and $impliesSideEffect) {
    Write-Output "ROUTING_CORRECTED: LOCAL_ROUTER cannot perform side-effecting work; rerouting $taskId to FUJITSU_CODEX."
    $primaryWorker = 'FUJITSU_CODEX'
    $decision.REASON = "$($decision.REASON) [corrected: LOCAL_ROUTER has no filesystem capability, task requires a real side effect]"
  }

  @{ task_id=$taskId; acquired_at=[DateTimeOffset]::Now.ToString('o'); worker=$primaryWorker; pid=$PID } |
    ConvertTo-Json | Set-Content -LiteralPath $leasePath -Encoding utf8
  Set-TaskStatus 'RUNNING' @{ selected_worker = $primaryWorker }
  Set-WorkerState $primaryWorker @{ busy_state='busy'; lease=$taskId; current_task=$taskId }

  if ($decision.ESCALATE -eq $true) {
    Set-TaskStatus 'WAITING_OWNER' @{ blocker = "LOCAL_ROUTER escalated: $($decision.REASON)" }
    Set-WorkerState $primaryWorker @{ busy_state='idle'; lease=$null; current_task=$null }
    Write-Output "ESCALATED: $taskId -> WAITING_OWNER ($($decision.REASON))"
    exit 0
  }

  if ($primaryWorker -eq 'FUJITSU_LOCAL_ROUTER') {
    # REAL self-execution (not just routing): ask the model to actually perform the task.
    $execPrompt = "You are FUJITSU_LOCAL_ROUTER executing a Task directly (not routing it). " +
      "Return ONLY one JSON object, single line, with keys: TASK_ID, STATUS (DONE or FAILED), OUTPUT (string), CONFIDENCE (HIGH/MEDIUM/LOW). " +
      "No prose outside the JSON. OBJECTIVE: $($task.objective) ACCEPTANCE_CRITERIA: $(($task.acceptance_criteria) -join '; ')"
    function ConvertTo-WinArg2([string]$Value) { '"' + ($Value -replace '"', '\"') + '"' }
    $argString = @('-m', (ConvertTo-WinArg2 ([string]$config.model_path)), '-p', (ConvertTo-WinArg2 $execPrompt),
                   '-n', [string]$config.n_predict, '--temp', [string]$config.temperature, '-st', '-t', [string]$config.threads) -join ' '
    $so = [IO.Path]::GetTempFileName(); $se = [IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath ([string]$config.runtime_binary) -ArgumentList $argString -NoNewWindow -PassThru -RedirectStandardOutput $so -RedirectStandardError $se
    $ok = $p.WaitForExit(180000)
    if (-not $ok) { try { Stop-Process -Id $p.Id -Force } catch {} }
    $raw = Get-Content -Raw -Encoding utf8 -LiteralPath $so -ErrorAction SilentlyContinue
    Remove-Item $so,$se -ErrorAction SilentlyContinue

    $execResult = $null
    if ($raw) {
      $js = $raw.IndexOf('{'); $je = $raw.LastIndexOf('}')
      if ($js -ge 0 -and $je -gt $js) {
        try { $execResult = $raw.Substring($js, $je-$js+1) | ConvertFrom-Json } catch {}
      }
    }

    $resultDir = Join-Path $busRoot 'results'; New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
    $execPath = Join-Path $resultDir "$taskId-exec.json"

    if ($execResult -and [string]$execResult.STATUS -eq 'DONE') {
      $execResult | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $execPath -Encoding utf8
      Set-TaskStatus 'COMPLETED' @{ output = [string]$execResult.OUTPUT; confidence = [string]$execResult.CONFIDENCE }
      Set-WorkerState $primaryWorker @{ busy_state='idle'; lease=$null; current_task=$null; last_result=$execPath }
      Write-Output "COMPLETED (self-executed by FUJITSU_LOCAL_ROUTER): $taskId -> $([string]$execResult.OUTPUT)"
    } else {
      @{ raw = $raw; parsed = $execResult } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $execPath -Encoding utf8
      Set-WorkerState $primaryWorker @{ busy_state='idle'; lease=$null; current_task=$null }
      $fb = [string]$decision.FALLBACK_WORKER
      if ($fb -and $fb -ne $primaryWorker -and $fb -eq 'FUJITSU_CLAUDE') {
        Set-TaskStatus 'REVIEW_WAIT' @{ blocker = "LOCAL_ROUTER self-execution did not return a valid DONE result; redispatched to fallback FUJITSU_CLAUDE per routing decision." }
        Write-Output "REDISPATCHED: $taskId -> REVIEW_WAIT (fallback FUJITSU_CLAUDE, LOCAL_ROUTER did not complete validly)"
      } else {
        Set-TaskStatus 'FAILED_RECOVERABLE' @{ blocker = 'LOCAL_ROUTER self-execution did not return a valid DONE result, and no usable FALLBACK_WORKER was named.' }
        Write-Output "FAILED_RECOVERABLE: $taskId (self-execution produced no valid result, no fallback available)"
      }
    }
  }
  elseif ($primaryWorker -eq 'FUJITSU_CLAUDE') {
    # FUJITSU_CLAUDE is the orchestrating agent itself - no subprocess to dispatch to; this Task
    # is hereby actionable by the current Claude Code session, not auto-completed here.
    Set-TaskStatus 'REVIEW_WAIT' @{ blocker = 'Assigned to FUJITSU_CLAUDE; requires the live Claude Code session to perform it (not a sub-process worker).' }
    Set-WorkerState $primaryWorker @{ busy_state='busy'; lease=$taskId; current_task=$taskId }
    Write-Output "PARKED: $taskId -> REVIEW_WAIT (assigned to FUJITSU_CLAUDE, the live session itself)"
  }
  elseif ($primaryWorker -eq 'FUJITSU_CODEX') {
    # Real bounded execution via codex exec, sandboxed to a fresh scratch dir (not the repo) -
    # workspace-write is confined to -C's directory, so blast radius is contained per-task.
    $codexBin = 'C:\Users\teppe\AppData\Local\OpenAI\Codex\bin\d375f7df50d3b421\codex.exe'
    $scratchDir = Join-Path $busRoot "scratch\$taskId"
    New-Item -ItemType Directory -Force -Path $scratchDir | Out-Null
    $lastMsgFile = Join-Path $scratchDir 'last-message.txt'
    $codexPrompt = "OBJECTIVE: $($task.objective) ACCEPTANCE_CRITERIA: $(($task.acceptance_criteria) -join '; ') " +
      "Work only inside the current directory. When done, state in one line what file(s) you created and their exact content."
    # Same Start-Process quoting rule as Invoke-DaimonLocalRouter.ps1: array elements with spaces
    # are NOT auto-quoted by -ArgumentList, so build one pre-quoted string ourselves.
    function ConvertTo-WinArg3([string]$Value) { '"' + ($Value -replace '"', '\"') + '"' }
    $codexArgString = @('exec', '-s', 'workspace-write', '-C', (ConvertTo-WinArg3 $scratchDir),
                        '--skip-git-repo-check', '-o', (ConvertTo-WinArg3 $lastMsgFile), (ConvertTo-WinArg3 $codexPrompt)) -join ' '
    $so = [IO.Path]::GetTempFileName(); $se = [IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath $codexBin -ArgumentList $codexArgString -NoNewWindow -PassThru -RedirectStandardOutput $so -RedirectStandardError $se

    # WaitForExit() alone proved unreliable here (DAIMON-TEST-011, 2026-09-30: codex finished and
    # wrote its output file correctly, but WaitForExit never returned - the wrapper hung ~15 min
    # until manually killed). Poll for the actual completion marker OR process exit instead, with
    # a hard deadline that force-kills either way so this can never hang indefinitely again.
    $deadline = (Get-Date).AddSeconds(240)
    $ok = $false
    while ((Get-Date) -lt $deadline) {
      if (Test-Path -LiteralPath $lastMsgFile) { $ok = $true; break }
      if ($p.HasExited) { $ok = $true; break }
      Start-Sleep -Seconds 3
    }
    if (-not $p.HasExited) { try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {} }
    $lastMsg = if (Test-Path -LiteralPath $lastMsgFile) { Get-Content -Raw -Encoding utf8 -LiteralPath $lastMsgFile } else { $null }
    $resultDir = Join-Path $busRoot 'results'; New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
    $execPath = Join-Path $resultDir "$taskId-exec.json"
    $createdFiles = @(Get-ChildItem -Path $scratchDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'last-message.txt' })
    if ($ok -and $lastMsg -and $createdFiles.Count -gt 0) {
      @{ status='DONE'; output=$lastMsg; created_files=@($createdFiles.Name); scratch_dir=$scratchDir } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $execPath -Encoding utf8
      Set-TaskStatus 'COMPLETED' @{ output = $lastMsg; created_files = @($createdFiles.Name) }
      Set-WorkerState $primaryWorker @{ busy_state='idle'; lease=$null; current_task=$null; last_result=$execPath; health='verified_execution_worker' }
      Write-Output "COMPLETED (FUJITSU_CODEX real execution, sandboxed to $scratchDir): $taskId"
    } else {
      @{ status='FAILED'; ok=$ok; last_message=$lastMsg; created_files=@($createdFiles.Name) } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $execPath -Encoding utf8
      Set-WorkerState $primaryWorker @{ busy_state='idle'; lease=$null; current_task=$null }
      # Worker停止 -> 別Workerへ再配車: don't just dead-end at FAILED_RECOVERABLE if the routing
      # decision already named a usable fallback.
      $fb = [string]$decision.FALLBACK_WORKER
      if ($fb -and $fb -ne $primaryWorker -and $fb -eq 'FUJITSU_CLAUDE') {
        Set-TaskStatus 'REVIEW_WAIT' @{ blocker = "FUJITSU_CODEX did not produce verifiable output; redispatched to fallback FUJITSU_CLAUDE per routing decision." }
        Write-Output "REDISPATCHED: $taskId -> REVIEW_WAIT (fallback FUJITSU_CLAUDE, FUJITSU_CODEX did not complete verifiably)"
      } else {
        Set-TaskStatus 'FAILED_RECOVERABLE' @{ blocker = 'FUJITSU_CODEX did not produce a verifiable file output within timeout, and no usable FALLBACK_WORKER was named.' }
        Write-Output "FAILED_RECOVERABLE: $taskId (FUJITSU_CODEX produced no verifiable output, no fallback available)"
      }
    }
    Remove-Item $so,$se -ErrorAction SilentlyContinue
  }
  elseif ($primaryWorker -like 'DYNABOOK_*') {
    Set-TaskStatus 'WAITING_PROVIDER' @{ blocker = "No verified cross-machine dispatch channel to $primaryWorker from FUJITSU yet; see NODE_REGISTRY.md Tailscale note." }
    Set-WorkerState $primaryWorker @{ busy_state='UNKNOWN'; lease=$null; current_task=$null }
    Write-Output "BLOCKED (honest, not simulated): $taskId -> WAITING_PROVIDER ($primaryWorker unreachable from FUJITSU)"
  }
  else {
    Set-TaskStatus 'WAITING_OWNER' @{ blocker = "PRIMARY_WORKER '$primaryWorker' has no dispatch path implemented yet." }
    Write-Output "PARKED: $taskId -> WAITING_OWNER (no dispatch path for $primaryWorker)"
  }
} finally {
  Remove-Item -LiteralPath $leasePath -Force -ErrorAction SilentlyContinue
}
exit 0
