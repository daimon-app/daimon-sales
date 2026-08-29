$ErrorActionPreference = 'Stop'
$server = Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'approval\ZeroApproval.ps1'))))

$publish = Get-AI5ZeroApprovalReview ([pscustomobject]@{ approvalType = 'external_publish' })
if ($publish.verdict -ne 'APPROVAL_OK' -or $publish.is_human_approval) { throw 'publish review failed' }
$payment = Get-AI5ZeroApprovalReview ([pscustomobject]@{ approvalType = 'payment' })
if ($payment.verdict -ne 'NOT_RECOMMENDED' -or $payment.recommended_action -ne 'REJECT') { throw 'payment review failed' }
$destructive = Get-AI5ZeroApprovalReview ([pscustomobject]@{ approvalType = 'destructive' })
if ($destructive.risks.Count -eq 0) { throw 'risk explanation missing' }
'ZERO_APPROVAL_TESTS_OK'
