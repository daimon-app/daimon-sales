# DAIMON CM build

公開候補CMの正本は `scripts/cm-master.md`。生成元は `build/build-cm-sales.ps1`、出力は `exports/` に置く。

## 初回のみ

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File marketing/cm/build/setup-ffmpeg.ps1`

FFmpeg公式ダウンロードページから案内されるGyan Windows buildを `.tools/` に取得する。`.tools/` はGit対象外で、システムPATHを変更しない。FFmpeg buildはGPLv3構成。FFmpegは制作ツールとしてのみ使用し、アプリへ同梱しない。

## 公開候補CM生成

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File marketing/cm/build/build-cm-sales.ps1`

出力: `cm-a-teaser-1080x1920.mp4`、`cm-b-product-flow-1080x1920.mp4`、`cm-c-purchase-1080x1920.mp4`

- 1080×1920 / 30fps / 7秒 / H.264 / yuv420p / faststart
- BGM・音声なし。字幕だけで意味が通る
- CM-Aはティザー、CM-Bは実フロー理解、CM-Cは21秒の購入判断用。
- 現行B/Cは最終AABと同じUIをEdgeでレンダーしたstaging合成版。公開前にsigned AABの実機録画へ差し替え、台帳へ端末・build hash・撮影日を記録する。
- `cm-a-morning-1080x1920.mp4`と`build-cm-a.ps1`は権利未確認の旧PWA画像を含むdeprecated成果物であり、公開・投稿・再生成は禁止。
