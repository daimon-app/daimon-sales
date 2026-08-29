$ErrorActionPreference='Stop';$server=Split-Path $PSScriptRoot
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $server 'adapters\BrowserSpecialistAdapter.ps1'))))
$g=New-AI5BrowserSpecialistRequest 'task_g' 'gemini' 'official docs'
if(!$g.require_sources-or$g.mode-ne'read_only'){throw'gemini request invalid'}
$m=New-AI5BrowserSpecialistRequest 'task_m' 'manus' 'inspect UI'
$gr=ConvertTo-AI5SpecialistResult $g 'found' @('official-source')
$mr=ConvertTo-AI5SpecialistResult $m 'checked'
$merged=Merge-AI5AgentResults @($gr,$mr)
if($merged.status-ne'SUCCESS'-or$merged.agents.Count-ne2){throw'result merge failed'}
try{New-AI5BrowserSpecialistRequest 'task_x' 'manus' 'publish' 'write';throw'write mode allowed'}catch{if($_.Exception.Message-eq'write mode allowed'){throw}}
if(!(Test-AI5SpecialistLiveEvidence 'gemini' 'GEMINI LIVE PASS' @('Gemini exact live response PASS'))){throw 'live evidence missing'}
if(Test-AI5SpecialistLiveEvidence 'gemini' 'GEMINI LIVE PASS' @('queued')){throw 'queued accepted'}
'BROWSER_SPECIALIST_ADAPTER_TESTS_OK'
