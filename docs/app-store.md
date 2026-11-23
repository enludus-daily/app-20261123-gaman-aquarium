# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.016 |
| アプリ名 | がまん水族館：買わずに育てる魚 / Wishfish: No-Buy Aquarium |
| サポート URL | https://github.com/enludus-daily/app-20261123-gaman-aquarium/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261123-gaman-aquarium/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」（暴力・性的表現・ギャンブル・Web 閲覧・ユーザー生成の共有・生成 AI なし）→ 4+ の見込み。本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：懐中電灯・壁紙・単純なタイマーなどではない。欲しい物ごとの冷ます時間・金額で決まる魚・図鑑・えさの育成を持つ。前日までのアプリ（うおさがし：昼の釣りパズル）と仕組みも見た目も違う
- 既存のアプリとの意味のある違い：No-Spend 系は日の連続や表。ここは欲しい物 1 つ＝卵 1 つの冷ます時間と、金額で魚が決まる水槽
- 長く使える価値（4.2）：我慢した合計の目盛り、図鑑 24 種（1 か月で 6〜9 種）、えさで育つ魚、毎日の問い 40 本
- 他社の名前・商標・見た目を使っていないか：使っていない（魚・水槽はすべて自作の Canvas）
- 金融の扱い：お金のやりとり・口座連携・投資の助言はしない（金額は利用者が入れるメモ）。カテゴリはライフスタイル
- Apple Intelligence：使わない

## 収益の道筋（本人が選ぶ）

- 買い切りの Pro ¥480（StoreKit 2、`com.enludus.daily.016.pro`）。広告なし
- 理由と勝算の表：README の「課金」

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ。金額・名前は端末の中だけ。通知はローカル通知）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
