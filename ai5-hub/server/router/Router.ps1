function Get-AI5Route {
  param([Parameter(Mandatory=$true)][string]$Message)
  $text = $Message.ToLowerInvariant()
  $primary = 'codex'; $secondary = @(); $kind = 'pc_task'
  if ($text -match '最新|調査|検索|google|比較|市場|ニュース') { $primary='gemini'; $kind='research' }
  if ($text -match 'web|ブラウザ|lp|販売準備|掲載|競合') { $primary='manus'; $kind='web_operation' }
  if ($text -match '厳密|監査|設計レビュー|仕様監査') { $primary='claude'; $kind='review' }
  if ($text -match 'コード|実装|修正|バグ|git|github|ファイル|windows|pc|テスト') { $primary='codex'; $kind='code' }
  if ($text -match '原因不明|難しいバグ|原因分析') { $primary='codex'; $secondary += 'claude' }
  if ($kind -eq 'code' -and $text -match '重要|本番|大規模|厳密') { $secondary += 'claude' }
  if ($text -match '販売準備') { $secondary += @('gemini','claude','codex') }
  $approvalPatterns = [ordered]@{
    external_publish='公開|本番公開|販売開始|リリース'; payment='課金|購入|決済|送金|契約|プラン変更';
    destructive='削除|消去|reset --hard|push --force'; credential='認証情報|パスワード|api.?key|トークン|アカウント変更'; external_send='メール送信|sns投稿|第三者へ送信'
  }
  $approvalType=$null
  foreach($entry in $approvalPatterns.GetEnumerator()){if($text -match $entry.Value){$approvalType=$entry.Key;break}}
  [ordered]@{
    objective=$Message; workType=$kind; primary=$primary; secondary=@($secondary|Select-Object -Unique|Where-Object{$_ -ne $primary});
    externalOperation=($kind -eq 'web_operation'); gitChange=($text -match 'git|github|コード|実装|修正');
    risk=if($approvalType){'high'}elseif($text -match '変更|修正|作成'){'medium'}else{'low'};
    requiresApproval=[bool]$approvalType; approvalType=$approvalType;
    doneWhen=if($kind -eq 'research'){'情報取得・比較・Zeroの結論'}elseif($kind -eq 'review'){'監査結果と指摘の整理'}else{'作業結果と検査結果の確認'}
  }
}

