# HabitSpark

[![App Store](https://img.shields.io/badge/App_Store-Download-blue?style=for-the-badge&logo=apple)](https://apps.apple.com/jp/app/id6762178668)
![Swift](https://img.shields.io/badge/Swift-5.10-orange?style=for-the-badge&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-blue?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

「やりたい」を、明日への活力に。

HabitSparkは、**KPT（Keep / Problem / Try）フレームワーク**を軸に、  
振り返りを通じて習慣の継続と行動改善を支援するiOSアプリです。

📱 **App Store**  
[HabitSpark - 振り返りで続くシンプル習慣化アプリ](https://apps.apple.com/app/habitspark-振り返りで続くシンプル習慣化アプリ/id6762178668)

---

## Why HabitSpark?

多くの習慣化アプリは「記録」はできても、  
**「なぜ続かなかったか」を振り返り、次に活かす設計** までは十分ではないと感じていました。

HabitSparkは、単なる行動記録ではなく、  
KPT（Keep / Problem / Try）による振り返りを通じて、  
**行動の改善まで支援する「続けられる習慣化」** を目指して設計しています。

---

## 🚀 Overview

HabitSparkは、単にタスクを管理するのではなく、  
**「振り返りを通じて行動を改善し、習慣を続ける」** ことを目的とした習慣化アプリです。

日々の行動を記録するだけでなく、  
KPT（Keep / Problem / Try）による振り返りを通して改善サイクルを回し、  
継続可能な習慣形成を支援します。

また、「未来の自分」を定義し、理想像までのステップを可視化することで、  
モチベーションを維持しながら目標達成へ進める設計になっています。

<img width="1400" height="418" alt="HabitSpark Overview" src="https://github.com/user-attachments/assets/2d324161-7355-4fd7-a4d9-c95d908addc8" />

<img width="1400" height="602" alt="HabitSpark Features" src="https://github.com/user-attachments/assets/98f43034-670b-4a04-9cac-1265ab48989c" />

---

## ✨ Features

### 📝 KPT Reflection
Keep / Problem / Try による日次・週次・月次の振り返り支援

### 🎯 Flexible Goal Management
日次・週次・月次の階層ごとに柔軟に目標を管理

### 🔮 Future Vision
理想の姿を定義し、未来の自分へのステップを可視化

### 📊 Progress Visualization
ストリーク表示・ヒートマップによる継続状況の可視化

### 📱 Home Widget
ホーム画面から今日のタスク確認・完了が可能

---

## 💡 Technical Highlights

### 🧠 Dual-Date Data Design

多くの習慣化アプリでは、月の途中で目標を追加すると、  
過去の達成率まで下がってしまう課題があります。

HabitSparkでは以下の2つの日付を分離して管理しています。

- **startDate**：統計計算に用いる基準日
- **targetDate**：UI上で表示する対象日

これにより、月途中・過去追加でも既存の統計データを壊さず、  
ユーザーの達成履歴を正しく保持できる設計を実現しました。

---

### 🔧 Stable Widget Rendering

WidgetKitの再描画時に発生する並び順の不安定さに対し、  
一意なID（UUID）を基準にソート処理を統一しました。

これにより、チェック操作時に一瞬だけ並び順が入れ替わる  
視覚的な違和感を解消し、ウィジェットの操作体験を改善しました。

---

## 🏗 Tech Stack

- **Language**: Swift 5.10+
- **Framework**: SwiftUI
- **Architecture**: MVVM
- **Persistence**: UserDefaults / Codable
- **Widget**: WidgetKit
- **Ads**: Google Mobile Ads SDK (AdMob)
- **Privacy**: App Tracking Transparency (ATT)

---

## 📝 Related Articles

設計・実装・改善の詳細は、以下の記事で公開しています。

- [タスク管理が続かない自分へ。SwiftUIで「未来の自分」に近づく目標達成アプリを開発しました](https://qiita.com/yoshiototora/items/2f9f2d8f8f9f3d6f0b6f)
- [未経験からKPT習慣化アプリをリリースするまでの全記録①｜Fat View脱却とデータ設計](https://qiita.com/yoshiototora/items/6f6d91a1d5a2e7f3c8ab)
- [[個人開発] 友達の「横で操作する手元」を見て気づいた改善点。HabitSpark v1.1.0 爆速アジャイル開発記録](https://qiita.com/yoshiototora/items/55dd6320f6068788060e)

---

## 👤 My Role

本プロジェクトは個人開発で行っており、以下を一貫して担当しました。

- **企画 / 要件定義**  
  コンセプト設計、機能設計、課題整理

- **UX / 情報設計**  
  KPT導線設計、継続しやすい導線設計、改善体験の設計

- **iOSアプリ開発**  
  SwiftUIによる実装、MVVMアーキテクチャ設計

- **データ / ロジック設計**  
  習慣継続を支えるデータ構造・統計ロジック設計

- **改善 / ユーザーテスト**  
  実利用ベースでの観察・改善サイクル運用

---

## 📄 License

MIT License
