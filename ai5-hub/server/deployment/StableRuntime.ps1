function Initialize-AI5StableRuntime([string]$ServerRoot,[string]$AppRoot) {
    $script:AI5DeploymentPath=Join-Path $ServerRoot 'runtime\deployment.json';New-Item -ItemType Directory -Force (Split-Path $script:AI5DeploymentPath)|Out-Null
    if(!(Test-Path $script:AI5DeploymentPath)){Save-AI5Deployment ([ordered]@{stableVersion='v42';stablePath=$AppRoot;candidateVersion='';candidatePath='';state='STABLE';tests=[ordered]@{};updatedAt=[DateTime]::UtcNow.ToString('o');lastFailure=''})}
}
function Save-AI5Deployment($Value){$Value.updatedAt=[DateTime]::UtcNow.ToString('o');$tmp="$script:AI5DeploymentPath.tmp";$Value|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $script:AI5DeploymentPath -Force}
function Get-AI5Deployment {Get-Content -Raw -Encoding UTF8 $script:AI5DeploymentPath|ConvertFrom-Json}
function Set-AI5UpdateCandidate([string]$Version,[string]$Path){$d=Get-AI5Deployment;$d.candidateVersion=$Version;$d.candidatePath=$Path;$d.state='TESTING';$d.lastFailure='';Save-AI5Deployment $d;$d}
function Complete-AI5ControlledSwitch($Checks){$d=Get-AI5Deployment;$required=@('unit','security','e2e','pwa');$failed=@($required|Where-Object{!$Checks.$_});if($failed.Count){$d.state='CANDIDATE_FAILED';$d.lastFailure='required_checks_failed: '+($failed-join',');$d.tests=$Checks;Save-AI5Deployment $d;return $d};$d.stableVersion=$d.candidateVersion;$d.stablePath=$d.candidatePath;$d.candidateVersion='';$d.candidatePath='';$d.tests=$Checks;$d.state='STABLE';Save-AI5Deployment $d;$d}
