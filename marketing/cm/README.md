# DAIMON CM build

CM-Aの正本は `scripts/cm-master.md`。生成元は `build/build-cm-a.ps1`、公式アプリ素材はビルド時にルート `index.html` から抽出し、出力は `exports/` に置く。

## 初回のみ

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File marketing/cm/build/setup-ffmpeg.ps1`

FFmpeg公式ダウンロードページから案内されるGyan Windows buildを `.tools/` に取得する。`.tools/` はGit対象外で、システムPATHを変更しない。FFmpeg buildはGPLv3構成。FFmpegは制作ツールとしてのみ使用し、アプリへ同梱しない。

## CM-A生成

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File marketing/cm/build/build-cm-a.ps1`

出力: `marketing/cm/exports/cm-a-morning-1080x1920.mp4`

- 1080×1920 / 30fps / 7秒 / H.264 / yuv420p / faststart
- BGM・音声なし。字幕だけで意味が通る
- 使用素材: DAIMON MORNING Editionの公式 `morning01` とブランドガイド準拠の自作エンドカード
- B〜EはCM-A検証後に同じ `build/` 構造へ追加する
