function Initialize-AI5Attachments {param([string]$ServerRoot);$script:AttachmentRoot=Join-Path $ServerRoot 'data\attachments';New-Item -ItemType Directory -Force $script:AttachmentRoot|Out-Null}
function Save-AI5Attachment {
 param($Body);$mime=[string]$Body.mime;if($mime-notin@('image/jpeg','image/png','image/webp')){throw 'unsupported_attachment_type'}
 try{$bytes=[Convert]::FromBase64String([string]$Body.base64)}catch{throw 'invalid_attachment'};if(!$bytes.Length-or$bytes.Length-gt5MB){throw 'attachment_size_limit'}
 $valid=if($mime-eq'image/jpeg'){$bytes.Length-gt2-and$bytes[0]-eq0xFF-and$bytes[1]-eq0xD8}elseif($mime-eq'image/png'){$bytes.Length-gt8-and$bytes[0]-eq0x89-and$bytes[1]-eq0x50-and$bytes[2]-eq0x4E-and$bytes[3]-eq0x47}else{$bytes.Length-gt12-and[Text.Encoding]::ASCII.GetString($bytes,0,4)-eq'RIFF'-and[Text.Encoding]::ASCII.GetString($bytes,8,4)-eq'WEBP'}
 if(!$valid){throw 'attachment_signature_mismatch'};$id='att_'+[guid]::NewGuid().ToString('N');$ext=@{'image/jpeg'='.jpg';'image/png'='.png';'image/webp'='.webp'}[$mime];[IO.File]::WriteAllBytes((Join-Path $script:AttachmentRoot ($id+$ext)),$bytes);[ordered]@{id=$id;mime=$mime;size=$bytes.Length;createdAt=[DateTime]::UtcNow.ToString('o')}
}
function Get-AI5AttachmentPath {param([string]$Id);if($Id-notmatch'^att_[a-f0-9]{32}$'){return $null};Get-ChildItem $script:AttachmentRoot -Filter ($Id+'.*') -File -ErrorAction SilentlyContinue|Select-Object -First 1 -ExpandProperty FullName}
