$ErrorActionPreference='Stop'
$hub=Resolve-Path (Join-Path $PSScriptRoot '..\..')
$taskSchema=Get-Content -Raw -Encoding UTF8 (Join-Path $hub 'shared\task.schema.json')|ConvertFrom-Json
$resultSchema=Get-Content -Raw -Encoding UTF8 (Join-Path $hub 'shared\result.schema.json')|ConvertFrom-Json
if($taskSchema.required-notcontains'writer'-or$taskSchema.required-notcontains'acceptance_criteria'){throw 'task contract incomplete'}
if($resultSchema.required-notcontains'evidence'-or$resultSchema.required-notcontains'resource_status'){throw 'result contract incomplete'}
$registry=Get-Content -Raw -Encoding UTF8 (Join-Path $hub 'project-control\registry.json')|ConvertFrom-Json
foreach($id in @('sales-m1-p02','sales-m2-daimon','sales-m3-ashita','sales-m4-meditation','sales-m5-switch')){if($registry.projects-notcontains$id){throw "missing factory project $id"};$p=Get-Content -Raw -Encoding UTF8 (Join-Path $hub "project-control\projects\$id.json")|ConvertFrom-Json;if(!$p.productId-or!$p.primaryAI-or!$p.writer){throw "incomplete factory project $id"}}
if($registry.projects-notcontains'sales-sns-daimon'){throw 'missing SNS mother project'}
$app=Get-Content -Raw -Encoding UTF8 (Join-Path $hub 'app.js');$html=Get-Content -Raw -Encoding UTF8 (Join-Path $hub 'index.html')
if($app-notmatch'renderSalesFactory'-or$html-notmatch'salesFactory'){throw 'factory dashboard missing'}
$script:saved=0;$script:dispatched=0
function Get-AI5Project([string]$Id){Get-Content -Raw -Encoding UTF8 (Join-Path $hub "project-control\projects\$Id.json")|ConvertFrom-Json}
function Get-AI5Task([string]$Id){$null}
function New-Task($Body,[string]$Id){[pscustomobject]@{task_id=$Id;product_id=$Body.productId;assigned_ai='placeholder';assignedPrimary='placeholder';assigned_agent='placeholder';writer='NONE';status='queued'}}
function Save-AI5Task($Task){$script:saved++}
function Dispatch-Task($Task){$script:dispatched++}
. ([ScriptBlock]::Create((Get-Content -Raw -Encoding UTF8 (Join-Path $hub 'server\orchestrator\SalesFactory.ps1'))))
$dry=Start-AI5SalesFactory -DryRun $true
if(@($dry.tasks).Count-ne12-or@($dry.tasks|Where-Object{$_.ai-eq'manus'}).Count-ne6-or@($dry.tasks|Where-Object{$_.ai-eq'gemini'}).Count-ne6){throw 'factory dry-run task count failed'}
if($script:saved-ne0-or$script:dispatched-ne0){throw 'dry-run persisted or dispatched'}
'SALES_FACTORY_V6_TESTS_OK'
