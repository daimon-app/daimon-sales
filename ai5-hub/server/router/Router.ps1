function Get-AI5ResourceStatus { param($Health,[bool]$AlwaysAvailable=$false);if($AlwaysAvailable){return 'AVAILABLE'};if(!$Health){return 'UNKNOWN'};if($Health.connection-eq'rate_limited'-or$Health.quota-eq'exhausted'){return 'EXHAUSTED'};if($Health.connection-eq'timeout'){return 'TIMEOUT'};if($Health.quota-eq'limited'){return 'LIMITED'};if([bool]$Health.available){return 'AVAILABLE'};'UNKNOWN' }

function Test-AI5ApprovalIntent {
  param([string]$Text)
  $patterns=[ordered]@{
    payment='課金|購入|決済|送金|有料契約|プラン変更|buy|pay|billing|subscribe'
    advertising='広告出稿|広告を出|promote\s+ad|run\s+ads?'
    authentication='oauth|2fa|二要素|captcha|本人確認|identity\s*verification|認証承認'
    external_publish='本番公開|公開投稿|販売開始|リリース|main\s*(へ|に)?\s*(merge|マージ)|google\s*play\s*(公開|release|publish)|deploy\s*(to\s*)?(production|prod)|publish\s*(to\s*)?(production|prod)'
    external_send='dm送信|dmを送|メール送信|sns投稿|第三者へ送信|send\s+(dm|email)|post\s+to\s+(x|instagram|tiktok|youtube)'
    credential='秘密情報.*外部|認証情報|パスワード|api.?key|bearer\s+|トークン|private\s*key|秘密鍵'
    destructive='不可逆|大量削除|リポジトリ削除|アカウント削除|reset\s+--hard|push\s+--force|force\s+push'
  }
  foreach($entry in $patterns.GetEnumerator()){if($Text-match$entry.Value){return $entry.Key}};$null
}

function Get-AI5Route {
  param([Parameter(Mandatory=$true)][string]$Message,$Resources=$null)
  $text=$Message.ToLowerInvariant();$primary='claude';$secondary=@();$kind='tech';$intent='task';$writer='claude'
  if($text-match'^(こんにちは|ありがとう|了解|おはよう|こんばんは)[。!！ ]*$'){$intent='conversation';$primary='zero';$kind='conversation';$writer='NONE'}
  elseif($text-match'キャンセル|中止|停止して'){$intent='cancel';$primary='zero';$kind='control';$writer='NONE'}
  elseif($text-match'市場|競合|価格|検索需要|レビュー|トレンド|海外事例|第二意見|調査|検索|ニュース'){$primary='gemini';$secondary=@('manus','claude');$kind='market_research';$writer='NONE'}
  elseif($text-match'販売|web|ブラウザ|lp|faq|特商法|返金|問い合わせ|sns|mobile|リンクqa|販売監査'){$primary='manus';$secondary=@('claude','gemini');$kind='sales_web';$writer='manus'}
  elseif($text-match'監査|設計レビュー|security|architecture|ux'){$primary='claude';$kind='audit';$writer='NONE'}
  elseif($text-match'ci|build|複雑|高難度|p0|重大bug|repository施工'){$primary='codex';$secondary=@('claude');$kind='critical_tech';$writer='codex'}
  elseif($text-match'コード|実装|修正|バグ|git|github|ファイル|windows|pc|テスト|migration|storage|pwa'){$primary='claude';$secondary=@('codex');$kind='tech';$writer='claude'}
  $approvalType=Test-AI5ApprovalIntent $text
  $resource=@{zero='AVAILABLE';manus='UNKNOWN';claude='UNKNOWN';gemini='UNKNOWN';codex='UNKNOWN'}
  if($Resources){foreach($name in @('manus','claude','gemini','codex')){if($Resources.$name){$resource[$name]=[string]$Resources.$name}}}
  if($resource[$primary]-in@('EXHAUSTED','TIMEOUT')){$fallback=@{manus='claude';claude=$(if($kind-match'sales|web'){'manus'}elseif($kind-match'research'){'gemini'}else{'codex'});gemini='manus';codex='claude'}[$primary];if($fallback){$secondary=@($secondary+$primary|Select-Object -Unique);$primary=$fallback;$writer=$(if($kind-match'research|audit'){'NONE'}else{$fallback})}}
  [ordered]@{objective=$Message;intent=$intent;workType=$kind;primary=$primary;secondary=@($secondary|Select-Object -Unique|Where-Object{$_-ne$primary});writer=$writer;resourceStatus=$resource;externalOperation=($kind-eq'sales_web');gitChange=($kind-match'tech');risk=$(if($approvalType){'high'}elseif($writer-ne'NONE'){'medium'}else{'low'});requiresApproval=[bool]$approvalType;approvalType=$approvalType;executionMode=$(if(@($secondary).Count){'parallel_safe'}else{'sequential'});doneWhen='担当AI結果・証拠・独立検査をZeroが照合し次工程を決定'}
}
