<#
DAIMON Tool Executor: OWNER_GATE (Japanese presentation for TRUE_OWNER_GATE decisions)
Exact allowed operation : format a structured gate description into the canonical Japanese
                          Owner-facing template (DAIMON_WORKER_ROUTING_SPEC.md Section 13.5).
                          Does not execute, approve, or bypass anything - pure text formatting.
Input schema            : -Operation, -Target, -Reason, -Impact, -ExternalPublish ('あり'/'なし'),
                          -Deletion ('あり'/'なし'), -Risk, -Recommendation ('承認'/'中止') - all
                          plain-string parameters, all mandatory except ExternalPublish/Deletion
                          (default 'なし') so risk is never silently dropped.
Path/scope restriction  : no file/network access at all - pure stdout formatting.
Timeout                 : n/a (instant, no subprocess).
Exit codes              : 0 always.
Result/Receipt/Evidence : prints the formatted Japanese template to stdout; caller (a TRUE_OWNER_GATE
                          code path) is responsible for actually presenting it and waiting for the
                          Owner's real decision - this tool only renders the text, it never decides.
#>
param(
  [Parameter(Mandatory=$true)][string]$Operation,
  [Parameter(Mandatory=$true)][string]$Reason,
  [Parameter(Mandatory=$true)][string]$Target,
  [Parameter(Mandatory=$true)][string]$Change,
  [string]$ExternalPublish = 'なし',
  [string]$Deletion = 'なし',
  [Parameter(Mandatory=$true)][string]$Risk,
  [ValidateSet('承認','中止')][string]$Recommendation = '承認'
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [Text.Encoding]::UTF8

if ([string]::IsNullOrWhiteSpace($Risk)) {
  throw 'RISK_FIELD_REQUIRED: 危険性の記載は省略不可。リスクがない場合も「低い」等、明示的に記載すること。'
}

@"
【本人承認が必要】

操作：$Operation
理由：$Reason
対象：$Target
変更内容：$Change
外部公開：$ExternalPublish
削除：$Deletion
危険性：$Risk
推奨：$Recommendation

1. 承認して進める
2. 中止する
"@ | Write-Output

exit 0
