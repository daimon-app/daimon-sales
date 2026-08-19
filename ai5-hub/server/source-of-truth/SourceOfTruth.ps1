function Get-AI5FileHashMetadata {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [ordered]@{ exists = $false; path = $Path; sha256 = $null; bytes = 0 }
    }

    $item = Get-Item -LiteralPath $Path
    [ordered]@{
        exists = $true
        path = $item.FullName
        sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        bytes = $item.Length
    }
}

function Get-AI5SourceOfTruthSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryPath,
        [string]$ExpectedBranch,
        [string]$ExpectedHead
    )

    $resolved = [IO.Path]::GetFullPath($RepositoryPath)
    if (!(Test-Path -LiteralPath $resolved -PathType Container)) { throw 'repository_path_not_found' }
    if (!(Test-Path -LiteralPath (Join-Path $resolved '.git'))) { throw 'not_a_git_worktree' }

    $branch = (& git -C $resolved branch --show-current 2>$null | Select-Object -First 1).Trim()
    $head = (& git -C $resolved rev-parse HEAD 2>$null | Select-Object -First 1).Trim()
    if ($LASTEXITCODE -ne 0 -or !$head) { throw 'git_head_unavailable' }

    $status = @(& git -C $resolved status --porcelain=v2 --branch --untracked-files=all 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'git_status_unavailable' }
    $diff = @(& git -C $resolved diff --no-ext-diff --no-color -- 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'git_diff_unavailable' }
    $stagedDiff = @(& git -C $resolved diff --cached --no-ext-diff --no-color -- 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'git_staged_diff_unavailable' }
    $worktreeStatus = @($status | Where-Object { $_ -notmatch '^# ' })

    $documentCandidates = [ordered]@{
        MASTER = @('MASTER.md', 'MASTER')
        AGENTS = @('AGENTS.md', 'AGENTS')
        ZERO_SPEC = @('ZERO_SPEC.md', 'ZERO_SPEC')
        README = @('README.md', 'README')
    }
    $documents = [ordered]@{}
    foreach ($name in $documentCandidates.Keys) {
        $selected = $null
        foreach ($candidate in $documentCandidates[$name]) {
            $candidatePath = Join-Path $resolved $candidate
            if (Test-Path -LiteralPath $candidatePath -PathType Leaf) { $selected = $candidatePath; break }
        }
        if ($selected) {
            $documents[$name] = Get-AI5FileHashMetadata $selected
        } else {
            $documents[$name] = [ordered]@{ exists = $false; path = $null; sha256 = $null; bytes = 0 }
        }
    }

    [ordered]@{
        repository_path = $resolved
        branch = $branch
        head = $head
        expected_branch = $(if ($ExpectedBranch) { $ExpectedBranch } else { $null })
        expected_head = $(if ($ExpectedHead) { $ExpectedHead.ToLowerInvariant() } else { $null })
        branch_matches = $(if ($ExpectedBranch) { $branch -eq $ExpectedBranch } else { $null })
        head_matches = $(if ($ExpectedHead) { $head -eq $ExpectedHead.ToLowerInvariant() } else { $null })
        dirty = $worktreeStatus.Count -gt 0
        status = $status
        diff = $diff
        staged_diff = $stagedDiff
        documents = $documents
        captured_at = [DateTime]::UtcNow.ToString('o')
    }
}

function Get-AI5GitHubSourceOfTruthSnapshot {
    param([Parameter(Mandatory=$true)][string]$Owner,[Parameter(Mandatory=$true)][string]$Repository,[Parameter(Mandatory=$true)][string]$Branch,[Parameter(Mandatory=$true)][string]$ExpectedHead,[scriptblock]$ApiInvoker)
    if(!$ApiInvoker){$ApiInvoker={param($Path) $raw=& gh api $Path 2>$null;if($LASTEXITCODE-ne0){throw "github_api_failed:$Path"};$raw}}
    $repoPath="repos/$Owner/$Repository";$commitRaw=& $ApiInvoker "$repoPath/commits/$ExpectedHead";$commit=$commitRaw|ConvertFrom-Json;if(!$commit.sha-or$commit.sha-ne$ExpectedHead){throw 'github_commit_mismatch'}
    $branchRaw=& $ApiInvoker "$repoPath/branches/$([Uri]::EscapeDataString($Branch))";$branchInfo=$branchRaw|ConvertFrom-Json;if(!$branchInfo.commit.sha-or$branchInfo.commit.sha-ne$ExpectedHead){throw 'github_branch_head_mismatch'}
    $documents=[ordered]@{};foreach($name in @('MASTER.md','AGENTS.md','ZERO_SPEC.md','README.md')){try{$raw=& $ApiInvoker "$repoPath/contents/$name`?ref=$ExpectedHead";$item=$raw|ConvertFrom-Json;$content=$null;$contentHash=$null;if($item.content-and$item.size-le1048576){$content=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(([string]$item.content-replace'\s','')));$sha=[Security.Cryptography.SHA256]::Create();try{$contentHash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($content)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}};$documents[$name]=[ordered]@{exists=$true;path=$item.path;sha=$item.sha;bytes=$item.size;content_sha256=$contentHash;content=$content}}catch{$documents[$name]=[ordered]@{exists=$false;path=$name;sha=$null;bytes=0;content_sha256=$null;content=$null}}}
    $inventory=@();if($commit.commit.tree.sha){try{$treeRaw=& $ApiInvoker "$repoPath/git/trees/$($commit.commit.tree.sha)?recursive=1";$tree=$treeRaw|ConvertFrom-Json;$inventory=@($tree.tree|Where-Object{$_.type-eq'blob'}|Select-Object -First 5000|ForEach-Object{[ordered]@{path=$_.path;sha=$_.sha;bytes=$_.size}})}catch{$inventory=@()}}
    $snapshot=[ordered]@{source='github_api';repository="$Owner/$Repository";visibility=$(if($commit.repository.private){'private'}else{'public_or_unknown'});branch=$Branch;head=$commit.sha;expected_head=$ExpectedHead;branch_matches=$true;head_matches=$true;documents=$documents;inventory=$inventory;commit_url=$commit.html_url;captured_at=[DateTime]::UtcNow.ToString('o')};$json=$snapshot|ConvertTo-Json -Depth 12 -Compress;$hash=[Security.Cryptography.SHA256]::Create();try{$snapshot.snapshot_sha256=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($json)))).Replace('-','').ToLowerInvariant()}finally{$hash.Dispose()};$snapshot
}
