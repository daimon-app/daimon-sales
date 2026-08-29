# AI5 HUB Owner Approval and Account Policy

## 正本ルール

Ownerの承認は本人にしかできない境界へ限定する。安全・可逆・非課金の通常施工はLEVEL 0として自動承認し、Evidenceを残して続行する。重要な外部公開・送信はLEVEL 1としてAI5 HUBへ日本語で提示し、承認Receipt受領後に自動再開する。金銭、契約、KYC、OTP、CAPTCHA、法的同意、秘密情報、不可逆操作はLEVEL 2として保護し、AIは代理承認しない。

承認ScopeはProject、操作、商品、国、価格、媒体、目的から算出する。完全一致する有効な承認だけ再利用し、差分のある承認へ拡張しない。分類不能はLEVEL 1、金銭・本人確認・法的同意の可能性があればLEVEL 2へFail Closedする。Gate中も対象外Taskと収益レーンは継続する。

## アカウント確認

SNS・販売・配信アカウントは、表示名だけで判断せず、Account ID、Channel ID、プロフィール、既存投稿、Channel Registry、Receipt、Decision、商品・国・言語Scopeを照合する。

- `VERIFIED_BY_AI5`: Registryと識別子が一致。Owner通知なしで続行。
- `WRONG_ACCOUNT`: 投稿禁止。Evidenceを保存し、正しいDAIMON販売アカウントを探索。
- `UNRESOLVED`: 当該媒体Taskだけ保留。他Taskを継続。単なる不明をOwner Gateにしない。

新規アカウント準備はAI5が行う。サービスが強制する本人確認、SMS/OTP、CAPTCHA、法的同意、秘密情報だけ本人操作通知へ送る。新規課金・有料広告・購入・契約は金額と継続条件を表示し、明示承認なしで実行しない。

## 通知

LEVEL 0と通常完了は無音で履歴へ保存する。本人操作、金銭、重大障害だけ通知し、緊急でない通知は集約する。通知待ち中もAI5全体を停止しない。
