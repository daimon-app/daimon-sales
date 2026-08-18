function Initialize-AI5LongMessages([string]$ServerRoot) {
    $script:LongMessageRoot = Join-Path $ServerRoot 'data\message-drafts'
    New-Item -ItemType Directory -Force $script:LongMessageRoot | Out-Null
}

function Get-AI5LongMessageId([string]$Id) {
    if ($Id -notmatch '^[A-Za-z0-9_-]{16,80}$') { throw 'invalid_message_id' }
    $Id
}

function Get-AI5LongMessagePath([string]$Id) { Join-Path $script:LongMessageRoot (Get-AI5LongMessageId $Id) }
function Read-AI5LongJson([string]$Path) { [IO.File]::ReadAllText($Path,[Text.UTF8Encoding]::new($false))|ConvertFrom-Json }
function Write-AI5LongJson($Value,[string]$Path) {$tmp="$Path.tmp";[IO.File]::WriteAllText($tmp,($Value|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false));Move-Item -LiteralPath $tmp -Destination $Path -Force}
function Get-AI5TextHash([string]$Text) {$sha=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}}

function New-AI5LongMessageDraft($Body) {
    $id=Get-AI5LongMessageId ([string]$Body.messageId);$count=[int]$Body.totalChunks;$length=[int]$Body.totalLength;$hash=([string]$Body.contentHash).ToLowerInvariant()
    if($count-lt1-or$count-gt64){throw 'invalid_chunk_count'}
    if($length-lt1-or$length-gt262144){throw 'message_too_large'}
    if($hash-notmatch '^[a-f0-9]{64}$'){throw 'invalid_content_hash'}
    $dir=Get-AI5LongMessagePath $id;$metaPath=Join-Path $dir 'draft.json'
    if(Test-Path $metaPath){$old=Read-AI5LongJson $metaPath;if($old.totalChunks-ne$count-or$old.totalLength-ne$length-or$old.contentHash-ne$hash){throw 'draft_conflict'};return Get-AI5LongMessageStatus $id}
    New-Item -ItemType Directory -Path $dir | Out-Null
    $now=[DateTime]::UtcNow.ToString('o');$meta=[ordered]@{messageId=$id;taskId=$null;totalChunks=$count;totalLength=$length;contentHash=$hash;state='RECEIVING';createdAt=$now;updatedAt=$now}
    Write-AI5LongJson $meta $metaPath
    Get-AI5LongMessageStatus $id
}

function Save-AI5LongMessageChunk([string]$Id,[int]$Index,$Body) {
    $dir=Get-AI5LongMessagePath $Id;$metaPath=Join-Path $dir 'draft.json';if(!(Test-Path $metaPath)){throw 'draft_not_found'};$meta=Read-AI5LongJson $metaPath
    if($meta.state-ne'RECEIVING'){throw 'draft_not_receiving'}
    if($Index-lt0-or$Index-ge[int]$meta.totalChunks){throw 'invalid_chunk_index'}
    $content=[string]$Body.content;if([string]::IsNullOrEmpty($content)-or$content.Length-gt16384){throw 'invalid_chunk_size'}
    $chunkHash=([string]$Body.chunkHash).ToLowerInvariant();if($chunkHash-notmatch'^[a-f0-9]{64}$'-or(Get-AI5TextHash $content)-ne$chunkHash){throw 'chunk_hash_mismatch'}
    $path=Join-Path $dir ("chunk-{0:D3}.txt" -f $Index)
    if(Test-Path $path){$old=[IO.File]::ReadAllText($path,[Text.UTF8Encoding]::new($false));if($old-ne$content){throw 'duplicate_chunk_conflict'};return Get-AI5LongMessageStatus $Id}
    [IO.File]::WriteAllText("$path.tmp",$content,[Text.UTF8Encoding]::new($false));Move-Item -LiteralPath "$path.tmp" -Destination $path
    $meta.updatedAt=[DateTime]::UtcNow.ToString('o');Write-AI5LongJson $meta $metaPath
    Get-AI5LongMessageStatus $Id
}

function Get-AI5LongMessageStatus([string]$Id) {
    $dir=Get-AI5LongMessagePath $Id;$path=Join-Path $dir 'draft.json';if(!(Test-Path $path)){throw 'draft_not_found'};$meta=Read-AI5LongJson $path
    $received=@(Get-ChildItem $dir -Filter 'chunk-*.txt' -ErrorAction SilentlyContinue|ForEach-Object{if($_.BaseName-match'chunk-(\d+)'){[int]$Matches[1]}}|Sort-Object -Unique)
    $missing=@(0..([int]$meta.totalChunks-1)|Where-Object{$_-notin$received})
    [ordered]@{messageId=$meta.messageId;taskId=$meta.taskId;state=$meta.state;receivedChunks=$received;receivedCount=$received.Count;totalChunks=[int]$meta.totalChunks;missingChunks=$missing;totalLength=[int]$meta.totalLength;createdAt=$meta.createdAt;updatedAt=$meta.updatedAt}
}

function Complete-AI5LongMessage([string]$Id) {
    $dir=Get-AI5LongMessagePath $Id;$metaPath=Join-Path $dir 'draft.json';if(!(Test-Path $metaPath)){throw 'draft_not_found'};$meta=Read-AI5LongJson $metaPath
    if($meta.state-eq'COMPLETED'){return [ordered]@{messageId=$meta.messageId;taskId=$meta.taskId;alreadyCompleted=$true}}
    $parts=@();for($i=0;$i-lt[int]$meta.totalChunks;$i++){$path=Join-Path $dir ("chunk-{0:D3}.txt" -f $i);if(!(Test-Path $path)){throw 'missing_chunk'};$parts += [IO.File]::ReadAllText($path,[Text.UTF8Encoding]::new($false))}
    $message=$parts-join'';if($message.Length-ne[int]$meta.totalLength){throw 'length_mismatch'};if((Get-AI5TextHash $message)-ne$meta.contentHash){throw 'content_hash_mismatch'}
    [ordered]@{messageId=$meta.messageId;message=$message;meta=$meta;metaPath=$metaPath}
}

function Set-AI5LongMessageCompleted($Completed,[string]$TaskId) {
    $meta=$Completed.meta;$meta.taskId=$TaskId;$meta.state='COMPLETED';$meta.updatedAt=[DateTime]::UtcNow.ToString('o');Write-AI5LongJson $meta $Completed.metaPath
}
