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

