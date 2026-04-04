//
//  ContentView.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/03.
//

import SwiftUI

// MARK: - データモデル（タスクの設計図）
struct Task: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// MARK: - 1. アプリの大枠（タブ画面）
struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("ホーム")
                }
            
            ReflectionView()
                .tabItem {
                    Image(systemName: "square.and.pencil")
                    Text("振り返り")
                }
            
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("カレンダー")
                }
        }
    }
}

// MARK: - 2. ホーム画面（タスク管理）
struct HomeView: View {
    // 複数のタスクを入れる配列（ロッカー）
    @State private var tasks: [Task] = [
        Task(title: "先行研究のサーベイを1本完了させる", isCompleted: true),
        Task(title: "データ集計のスクリプトを書く", isCompleted: false)
    ]
    // 入力欄のテキストを保存する変数
    @State private var newTaskTitle = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // ▼ 新規タスク追加エリア ▼
                HStack {
                    TextField("新しいタスクを入力...", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: addTask) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
                // ▼ タスク一覧エリア ▼
                List {
                    Section(header: Text("今日のサブタスク")) {
                        // 配列の中身を順番に取り出して表示
                        ForEach($tasks) { $task in
                            Button(action: {
                                task.isCompleted.toggle()
                            }) {
                                HStack {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(task.isCompleted ? .green : .gray)
                                        .font(.title2)
                                    
                                    Text(task.title)
                                        .strikethrough(task.isCompleted, color: .gray)
                                        .foregroundColor(task.isCompleted ? .gray : .primary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete(perform: deleteTasks) // スワイプで削除
                    }
                }
            }
            .navigationTitle("今日の目標")
        }
    }
    
    // タスクを追加する処理
    func addTask() {
        if !newTaskTitle.isEmpty {
            tasks.append(Task(title: newTaskTitle))
            newTaskTitle = "" // 入力欄を空にする
        }
    }
    
    // タスクを削除する処理
    func deleteTasks(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }
}

// MARK: - 3. 振り返り画面（KPT法）
struct ReflectionView: View {
    @State private var keepText = ""
    @State private var problemText = ""
    @State private var tryText = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Keep (良かったこと・続けること)")) {
                    TextEditor(text: $keepText)
                        .frame(height: 80)
                }
                
                Section(header: Text("Problem (課題・反省点)")) {
                    TextEditor(text: $problemText)
                        .frame(height: 80)
                }
                
                Section(header: Text("Try (次に挑戦すること・改善策)")) {
                    TextEditor(text: $tryText)
                        .frame(height: 80)
                }
                
                // 保存ボタン
                Button(action: {
                    print("保存ボタンが押されました")
                }) {
                    Text("振り返りを保存する")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .listRowBackground(Color.clear) // 背景を透明にしてボタンだけ目立たせる
            }
            .navigationTitle("今日の振り返り")
        }
    }
}

// MARK: - 4. カレンダー画面（ヒートマップ風）
struct CalendarView: View {
    // 7列のグリッド（マス目）を作る設定
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("活動ヒートマップ（モックアップ）")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    // カレンダーのマス目を描画
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(1...30, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 4)
                                // 達成度合いによって緑の濃さが変わるイメージ（乱数でランダムな濃さにしています）
                                .fill(Color.green.opacity(Double.random(in: 0.1...1.0)))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Text("\(day)")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("カレンダー")
        }
    }
}

// MARK: - プレビュー用
#Preview {
    ContentView()
}
