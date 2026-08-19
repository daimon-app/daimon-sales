$ErrorActionPreference = 'Stop'
$server = Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'source-of-truth\SourceOfTruth.ps1'))))

$repo = (Resolve-Path (Join-Path $server '..\..')).Path
$branch = (& git -C $repo branch --show-current).Trim()
$head = (& git -C $repo rev-parse HEAD).Trim()
$snapshot = Get-AI5SourceOfTruthSnapshot -RepositoryPath $repo -ExpectedBranch $branch -ExpectedHead $head
if (!$snapshot.branch_matches -or !$snapshot.head_matches) { throw 'expected_ref_match_failed' }
if (!$snapshot.documents.AGENTS.exists -or !$snapshot.documents.AGENTS.sha256) { throw 'agents_metadata_missing' }
if ($snapshot.documents.ZERO_SPEC.exists -and !$snapshot.documents.ZERO_SPEC.sha256) { throw 'zero_spec_hash_missing' }
if ($null -eq $snapshot.status -or $null -eq $snapshot.diff -or $null -eq $snapshot.staged_diff) { throw 'git_evidence_missing' }
$mismatch = Get-AI5SourceOfTruthSnapshot -RepositoryPath $repo -ExpectedBranch '__wrong_branch__' -ExpectedHead ('0' * 40)
if ($mismatch.branch_matches -or $mismatch.head_matches) { throw 'mismatch_not_detected' }
'SOURCE_OF_TRUTH_TESTS_OK'

