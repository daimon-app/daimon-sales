# 公開・販売ゲート

`GO`は下記がすべて実証されるまで出さない。未確定情報を推測で埋めない。

## 商品・Android（アプリ本体工程）

- [x] Morning専用のprivate Android Repositoryとsigned AAB/APK
- [x] approved applicationId / versionCode / minSdk / targetSdk / 権限 / SDK一覧
- [x] upload-key署名、artifact-level権限/DEX/秘密/lint監査
- [ ] signed APKの実機QA
- [x] 販売本体と公開RepositoryのGit配布境界
- [x] 初回説明、アプリ情報、保存情報説明・削除へのアプリ内導線
- [ ] 正式法務・問い合わせ先のアプリ内反映

## 本人承認・正式情報

- [ ] 正式販売事業者、責任者、住所・電話の必要表示
- [ ] 正式問い合わせ先
- [ ] 返品・キャンセル条件と最終法務確認
- [ ] 対象国、490円のConsole最終設定
- [ ] Data safety、広告、app access、対象年齢、IARC最終回答
- [ ] LP公開、Play審査提出、販売開始、SNS実投稿

## 販売素材・E2E

- [ ] signed AABと同一buildの実機スクリーンショット（現行5枚はstaging UI証跡）
- [ ] CM-B/Cをsigned APKの実機操作映像へ差し替え（現行MP4はstaging合成版、CM-C 21秒SSOTはFIXED）
- [x] 採用素材の作成者・出典・商用利用範囲を記録した権利台帳
- [ ] 正規LP URL、Play URL、媒体別UTM実リンク台帳
- [x] SNS→LP→Play→購入→install→初回起動→朝開始→問い合わせのstaging境界表（外部URL/購入/実機は承認待ち）
- [ ] 新規個人アカウントに該当する場合のclosed test要件をConsoleで確認・完了
