function Get-AI5TaskProjectId($Task) {
    if($Task.projectContext.projectId){return [string]$Task.projectContext.projectId}
    if($Task.project_id){return [string]$Task.project_id}
    if(([string]$Task.message)-match'(?i)AI5\s*HUB|AI5HUB'){return 'ai5-hub'}
    $null
}
function Test-AI5ReadOnlyTask($Task) {
    if($Task.requested_read_only){
      $explicit=([string]$Task.message)-replace'変更(せず|しない|禁止)',''-replace'一切変更せず',''
      if($explicit-match'(?i)(read.?only|読み取り専用)' -and $explicit-notmatch'(修正|変更|実装|書込|削除|commit|push|公開|送信|購入|支払|契約)'){return $true}
    }
    if($Task.route.gitChange-or$Task.route.externalOperation){return $false}
    if($Task.route.workType-in@('research','review','knowledge_lookup')){return $true}
    # A prohibition such as "変更せず" describes the safety boundary, not a write request.
    $text=([string]$Task.message)-replace'変更(せず|しない|禁止)',''
    $text-match'(?i)(status|履歴|確認だけ|read.?only|閲覧|検索|調査|レビュー)'-and$text-notmatch'(修正|変更|実装|書込|直して)'
}
function Get-AI5TaskQueueDecision($Task,$Tasks,$Locks) {
    $project=Get-AI5TaskProjectId $Task;$readOnly=Test-AI5ReadOnlyTask $Task
    if(!$project){return [ordered]@{action='DISPATCH';reason='NO_PROJECT_CONFLICT';projectId=$null;readOnly=$readOnly}}
    $freshAfter=[DateTime]::UtcNow.AddMinutes(-30)
    $active=@($Tasks|Where-Object{
        $fresh=$true
        if($_.updatedAt){try{$fresh=([DateTime]::Parse([string]$_.updatedAt).ToUniversalTime()-ge$freshAfter)}catch{$fresh=$true}}
        $_.taskId-ne$Task.taskId-and(Get-AI5TaskProjectId $_)-eq$project-and$_.status-in@('planning','running','reviewing','retrying')-and$fresh
    })
    $locked=@($Locks|Where-Object{$_.projectId-eq$project}).Count-gt0
    if($readOnly){return [ordered]@{action='DISPATCH';reason='READ_ONLY_PARALLEL';projectId=$project;readOnly=$true}}
    if($active.Count-or$locked){return [ordered]@{action='QUEUE';reason='SINGLE_WRITER_BUSY';projectId=$project;readOnly=$false}}
    [ordered]@{action='DISPATCH';reason='WRITER_AVAILABLE';projectId=$project;readOnly=$false}
}
