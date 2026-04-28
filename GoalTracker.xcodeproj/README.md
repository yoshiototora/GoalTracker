# HabitSpark
「やりたい」を、明日への活力に。

📱 **App Store**

[HabitSpark-振り返りで続くシンプル習慣化アプリ](https://apps.apple.com/app/habitspark-振り返りで続くシンプル習慣化アプリ/id6762178668)

HabitSparkは、KPT（Keep / Problem / Try）フレームワークを軸にした、振り返りと習慣化のためのiOSアプリケーションです。

---

## 🚀 アプリの概要

ただタスクをこなすだけでなく、「振り返り」を通じて自分自身の行動を改善していくことを目的としています。

「未来の自分」を定義し、そこに至るまでの道のりを視覚化することで、モチベーションを維持しながら目標達成をサポートします。

<img width="1400" height="418" alt="image" src="https://github.com/user-attachments/assets/2d324161-7355-4fd7-a4d9-c95d908addc8" />

<img width="1400" height="602" alt="image" src="https://github.com/user-attachments/assets/98f43034-670b-4a04-9cac-1265ab48989c" />



---

## ✨ 主な機能

### 📝 KPT振り返り
日次・週次・月次で「Keep / Problem / Try」を整理し、行動の改善サイクルを回せます。

### 🎯 フレキシブルな目標設定
日次・週次・月次それぞれの階層で目標を管理できます。

### 🔮 未来の自分（Future Vision）
長期的なビジョンを小さなステップに分解し、進捗を可視化します。

### 📊 継続の可視化
ストリーク表示やヒートマップにより、習慣の継続状況を直感的に把握できます。

### 📱 iOSウィジェット
ホーム画面から今日のタスクを素早く確認・完了できます。

---

## 🛠 v1.1.0 アップデートのこだわり

今回のアップデートでは、対面でのユーザーテスト（アジャイル開発）を通して、**ユーザーの心理的安全性を守る設計**に注力しました。

### 🧠 過去の達成率を守る「二重日付管理」

多くの習慣化アプリでは、月の途中で目標を追加すると過去の達成率が下がってしまう問題があります。

HabitSparkでは以下の2つを分離しました：

- **startDate**：統計計算の分母の基準日  
- **targetDate**：UI上で表示する日付  

これにより、過去にさかのぼって記録しても、統計データが壊れない設計を実現しています。

---

### 🔧 ウィジェットの描画安定化

WidgetKitの再描画時に発生する順序の不安定さに対して、**一意なID（UUID）によるソートを統一**。

これにより、チェック操作時に発生していた一瞬の並び替わり（UXの違和感）を解消しました。

---

## 🏗 技術スタック

- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Architecture**: MVVM
- **Database**: UserDefaults / Codable（ファイルベース）
- **Widget**: WidgetKit
- **Ad**: Google Mobile Ads SDK（AdMob）
- **Privacy**: App Tracking Transparency（ATT）対応

---

## 👥 開発チーム（Takadalab）

本プロジェクトは3名のチームで開発しています。

- **Project Manager / Researcher**  
  企画・UXリサーチ・振り返りフレームワーク設計

- **Developer（iOS）**  
  実装・ロジック設計（本リポジトリのメインメンテナー）

- **Engineer**  
  インフラ・システム構成

---

## 📄 ライセンス

MIT License

---
