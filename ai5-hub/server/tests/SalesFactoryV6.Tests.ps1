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
'SALES_FACTORY_V6_TESTS_OK'
