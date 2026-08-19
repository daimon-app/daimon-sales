function Get-AI5SalesFactoryProjects {
  @('sales-m1-p02','sales-m2-daimon','sales-m3-ashita','sales-m4-meditation','sales-m5-switch','sales-sns-daimon')|ForEach-Object{Get-AI5Project $_}|Where-Object{$_}
}
function Start-AI5SalesFactory {
  param([bool]$DryRun=$true)
  $created=@();foreach($project in Get-AI5SalesFactoryProjects){
    $repo="$($project.repository.owner)/$($project.repository.name)";$base="Product $($project.productId) $($project.name). GitHub source $repo branch $($project.repository.activeBranch) commit $($project.repository.latestCommit)."
    $isSns=($project.productId-eq'SNS')
    $jobs=@(
      [ordered]@{agent='manus';message="$base 販売準備をread-onlyで監査し、市場・競合・position・価格・商品説明・LP・FAQ・privacy・terms・特商法・返金・問い合わせ・SNS・mobile・link・browser QAをSALES READY直前まで設計してください。公開・投稿・購入・main mergeは禁止。";acceptance=@('販売20工程の判定','証拠URLまたはGitHub path','blocker分類','OWNER_INFO_REQUIRED分離')},
      [ordered]@{agent='gemini';message="$base 市場、競合、価格、SNSトレンド、検索需要、review不満、海外事例、差別化を独立調査してください。重要事項は一次情報sourceを付け、販売施工はしないでください。";acceptance=@('一次情報source','競合比較','価格根拠','差別化提案')}
    )
    if($isSns){$jobs[0].message="$base DAIMON公式SNS母艦（Instagram/TikTok/YouTube/X）の既存アカウントと導線をread-only監査し、重複作成せず販売母艦へ接続する施工仕様を返してください。公開投稿・DM・広告・購入は禁止。";$jobs[0].acceptance=@('既存アカウント監査','4媒体導線仕様','重複防止','公開操作なし');$jobs[1].message="$base DAIMON公式SNS母艦の4媒体について、市場・トレンド・競合・投稿形式を独立調査し一次情報source付きで返してください。アカウント作成・投稿は禁止。";$jobs[1].acceptance=@('4媒体調査','一次情報source','競合比較','投稿仮説')}
    foreach($job in $jobs){$id="task_factory_$($project.productId.ToLowerInvariant())_$($job.agent)_v6";$existing=if($DryRun){$null}else{Get-AI5Task $id};if($existing){$created+=,$existing;continue};$body=[pscustomobject]@{taskId=$id;projectId=$project.projectId;productId=$project.productId;message=$job.message;operation='read_only';source='ZERO_FACTORY';priority='high';conversationId='sales-factory-v6';writer='NONE';sourceCommit=$project.repository.latestCommit;expectedOutput='Zero Return Result v6';acceptanceCriteria=$job.acceptance;constraints=@('read only','no main merge','no production publish','no SNS publish','no purchase')};$task=New-Task $body $id;if($task.assignedPrimary-ne$job.agent){$task.assignedPrimary=$job.agent;$task.assigned_ai=$job.agent;$task.assigned_agent=$job.agent;$task.writer='NONE'};$created+=,$task;if(!$DryRun){Save-AI5Task $task;Dispatch-Task $task}}
  };[ordered]@{factory_id='ai5-sales-factory-v6';dry_run=$DryRun;tasks=@($created|ForEach-Object{[ordered]@{task_id=$_.task_id;product_id=$_.product_id;ai=$_.assigned_ai;status=$_.status}});created_at=[DateTime]::UtcNow.ToString('o')}
}
