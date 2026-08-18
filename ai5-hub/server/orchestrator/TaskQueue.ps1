function Get-AI5TaskProjectId($Task) {
    if($Task.projectContext.projectId){return [string]$Task.projectContext.projectId}
    if($Task.project_id){return [string]$Task.project_id}
    if(([string]$Task.message)-match'(?i)AI5\s*HUB|AI5HUB'){return 'ai5-hub'}
    $null
}
function Test-AI5ReadOnlyTask($Task) {
    if($Task.route.gitChange-or$Task.route.externalOperation){return $false}
    if($Task.route.workType-in@('research','review','knowledge_lookup')){return $true}
    ([string]$Task.message)-match'(?i)(status|履歴|確認だけ|read.?only|閲覧|検索|調査|レビュー)'-and([string]$Task.message)-notmatch'(修正|変更|実装|書込|直して)'
}
function Get-AI5TaskQueueDecision($Task,$Tasks,$Locks) {
    $project=Get-AI5TaskProjectId $Task;$readOnly=Test-AI5ReadOnlyTask $Task
    if(!$project){return [ordered]@{action='DISPATCH';reason='NO_PROJECT_CONFLICT';projectId=$null;readOnly=$readOnly}}
    $active=@($Tasks|Where-Object{$_.taskId-ne$Task.taskId-and(Get-AI5TaskProjectId $_)-eq$project-and$_.status-in@('planning','running','reviewing','retrying')})
    $locked=@($Locks|Where-Object{$_.projectId-eq$project}).Count-gt0
    if($readOnly){return [ordered]@{action='DISPATCH';reason='READ_ONLY_PARALLEL';projectId=$project;readOnly=$true}}
    if($active.Count-or$locked){return [ordered]@{action='QUEUE';reason='SINGLE_WRITER_BUSY';projectId=$project;readOnly=$false}}
    [ordered]@{action='DISPATCH';reason='WRITER_AVAILABLE';projectId=$project;readOnly=$false}
}
