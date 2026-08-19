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
$remoteHead='a'*40;$encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('document'));$api={param($Path);if($Path-match'/commits/'){return (@{sha=$remoteHead;html_url='https://github.example/commit';commit=@{tree=@{sha='tree1'}};repository=@{private=$true}}|ConvertTo-Json -Depth 5)};if($Path-match'/branches/'){return (@{commit=@{sha=$remoteHead}}|ConvertTo-Json)};if($Path-match'/git/trees/'){return (@{tree=@(@{type='blob';path='README.md';sha='blob';size=10})}|ConvertTo-Json -Depth 5)};return (@{path='README.md';sha='blob';size=8;content=$encoded}|ConvertTo-Json)}
$remote=Get-AI5GitHubSourceOfTruthSnapshot -Owner 'owner' -Repository 'repo' -Branch 'product/test' -ExpectedHead $remoteHead -ApiInvoker $api
if(!$remote.head_matches-or$remote.documents.'README.md'.sha-ne'blob'-or!$remote.documents.'README.md'.content_sha256-or$remote.inventory.Count-ne1-or!$remote.snapshot_sha256){throw 'remote source snapshot failed'}
'SOURCE_OF_TRUTH_TESTS_OK'
