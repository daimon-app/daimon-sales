# DAIMON Morning Voice Prototype — AivisSpeech v1

> **未採用の試作品です。DAIMON販売版の正式音声資産ではありません。**
>
> 試聴・採用判断後、承認された音声だけを正式な `assets` / Audio Packへ昇格します。

## 基準

- Repository: `daimon-app/daimon-sales`
- Base HEAD: `e5ba2bbcb3127f364dac86782c0465f0095fbc66`
- Prototype branch: `feat/aivisspeech-morning-voice-test`
- Source text: `languagePacks.ja.morning.slides`
- 対象: 朝12スライド × 男性・女性 = 24ファイル
- DAIMON本体への組み込み: なし

## 使用モデル

### 男性

- AivisSpeech: **阿井田 茂 / Calm**
- AivisHub UUID: `47e53151-a378-46f3-abee-ce13aa07feb1`
- Style: Calm（local style ID 1）
- AIVMX SHA-256: `6dabe29de5ec2c1715e12a430805e1bff6ec64a315cccec2d26fad029df83243`

### 女性

- AivisSpeech: **まお / おちつき**
- AivisHub UUID: `a59cb814-0083-4369-8542-f51a29e72af7`
- Style: おちつき（local style ID 3）
- AIVMX SHA-256: `f87ccea2e8e2de0e0bfe52e803945af903b4086bf25621a015111628f00e4119`

## 生成設定

- AivisSpeech Engine 1.0.0、CPU、ローカル生成
- 男性 `speedScale`: 0.92
- 女性 `speedScale`: 0.90
- 読み順: main → 0.65秒 → support → 0.80秒 → impact → 1.00秒
- 名前レイヤー: 読み上げなし
- 文章: 基準HEADの朝12文章を変更せず使用
- 音量正規化: EBU R128 loudnorm（I=-18 LUFS、TP=-1.5 dBTP、LRA=7）
- 形式: MP3 / mono / 44.1kHz / 96kbps CBR
- 男性合計: 127.90秒 / 1,544,987 bytes
- 女性合計: 138.48秒 / 1,671,629 bytes
- 24本合計: 266.38秒 / 3,216,616 bytes

## ライセンス

両モデルとも **Aivis Common Model License (ACML) 1.0** です。

- 商用利用: 可（禁止事項に該当しない営利利用）
- DAIMON有料販売版での固定生成音声利用: 可
- 生成音声のアプリ同梱・配布: 可
- クレジット: 任意
- 「まお」は、表記する場合 `AivisSpeech: まお` がモデル説明で案内されています
- モデルファイル自体を再配布する場合はACML本文の添付が必要です
- なりすまし、話者の尊厳を傷つける利用、攻撃・差別、虚偽情報、虚偽・誇大広告、政治・宗教・陰謀論の扇動、犯罪・反社会的利用等は禁止されています

## パッケージ

- ZIP: `../packages/DAIMON-AivisSpeech-morning-voice-test.zip`
- ZIP SHA-256: `3F5CFC3F89F293D8F9B741B98BB52EF86D0567B070FBF7C04BAFE8554A11A093`
- ZIP容量: 2,369,949 bytes
- 内容: `male/` 12本、`female/` 12本、生成情報README

## 昇格ルール

1. `prototypes/` 内で試聴する
2. 男性・女性それぞれ採用または再試作を決定する
3. 採用決定後のみ正式Audio Packへコピーする
4. 正式組み込み時に音声終了同期、VOICE切替、PWAキャッシュを別途検証する

