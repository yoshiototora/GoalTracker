//
//  ContentView.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/03.
//

import SwiftUI

// アプリの大枠となるタブ画面
struct ContentView: View {
    var body: some View {
        TabView {
            // 1. ホーム画面
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("ホーム")
                }
            
            // 2. 振り返り画面
            ReflectionView()
                .tabItem {
                    Image(systemName: "square.and.pencil")
                    Text("振り返り")
                }
            
            // 3. カレンダー画面
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("カレンダー")
                }
        }
    }
}

// ホーム画面の中身
struct HomeView: View {
    // チェックの状態を管理する変数
    @State private var task1Completed = false
    @State private var task2Completed = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("今日のサブタスク")) {
                    
                    // ▼ タスク1 ▼
                    Button(action: {
                        // タップした時にチェックを反転させる
                        task1Completed.toggle()
                    }) {
                        HStack {
                            // アイコン部分（チェックの有無で画像を切り替え）
                            Image(systemName: task1Completed ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task1Completed ? .green : .gray)
                                .font(.title2) // アイコンを少し大きめにして押しやすくする
                            
                            // テキスト部分
                            Text("先行研究のサーベイを1本完了させる")
                                .strikethrough(task1Completed, color: .gray)
                                .foregroundColor(task1Completed ? .gray : .primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle()) // これを入れることで行全体が青文字になるのを防ぐ
                    
                    // ▼ タスク2 ▼
                    Button(action: {
                        task2Completed.toggle()
                    }) {
                        HStack {
                            Image(systemName: task2Completed ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task2Completed ? .green : .gray)
                                .font(.title2)
                            
                            Text("データ集計のスクリプトを書く")
                                .strikethrough(task2Completed, color: .gray)
                                .foregroundColor(task2Completed ? .gray : .primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                }
            }
            .navigationTitle("今日の目標")
        }
    }
}

// 振り返り画面
struct ReflectionView: View {
    var body: some View {
        Text("ここにKPTを入力する画面を作ります")
    }
}

// カレンダー画面
struct CalendarView: View {
    var body: some View {
        Text("ここにヒートマップのカレンダーを作ります")
    }
}
