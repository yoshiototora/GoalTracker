//
//  ContentView.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/03.
//

import SwiftUI
import Combine

// MARK: - データモデル（1日分の記録）
struct DailyNote {
    var tasks: [Task] = []
    var keep: String = ""
    var problem: String = ""
    var tryText: String = ""
    var weeklyReflection: String = ""
    var monthlyReflection: String = ""
}

struct Task: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// MARK: - データ管理（日付ごとにデータを保存するロッカー）
class AppDataManager: ObservableObject {
    @Published var reflections: [String: DailyNote] = [:] // "2026-04-05" のような文字列を鍵にして保存
    @Published var selectedDate: Date = Date()
    
    // 指定した日付のデータを取得または新規作成
    func getNote(for date: Date) -> DailyNote {
        let key = dateKey(date)
        return reflections[key] ?? DailyNote()
    }
    
    // データを保存
    func saveNote(_ note: DailyNote, for date: Date) {
        let key = dateKey(date)
        reflections[key] = note
    }
    
    func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - 1. アプリ全体の大枠
struct ContentView: View {
    @StateObject private var dataManager = AppDataManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(dataManager: dataManager)
                .tabItem {
                    Image(systemName: "house")
                    Text("ホーム")
                }
                .tag(0)
            
            ReflectionView(dataManager: dataManager)
                .tabItem {
                    Image(systemName: "square.and.pencil")
                    Text("振り返り")
                }
                .tag(1)
            
            CalendarView(dataManager: dataManager, selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("カレンダー")
                }
                .tag(2)
        }
    }
}

// MARK: - 2. ホーム画面（タスク管理）
struct HomeView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var newTaskTitle = ""
    
    var body: some View {
        let currentNote = dataManager.getNote(for: dataManager.selectedDate)
        
        NavigationView {
            VStack {
                Text(dataManager.dateKey(dataManager.selectedDate) + " のタスク")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    TextField("新しいタスク（研究、就活など）...", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: addTask) {
                        Image(systemName: "plus.circle.fill").font(.title)
                    }
                }
                .padding()
                
                List {
                    ForEach(currentNote.tasks) { task in
                        HStack {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? .green : .gray)
                            Text(task.title)
                                .strikethrough(task.isCompleted)
                        }
                        .onTapGesture { toggleTask(task) }
                    }
                    .onDelete(perform: deleteTask)
                }
            }
            .navigationTitle("今日の目標")
        }
    }
    
    func addTask() {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        if !newTaskTitle.isEmpty {
            note.tasks.append(Task(title: newTaskTitle))
            dataManager.saveNote(note, for: dataManager.selectedDate)
            newTaskTitle = ""
        }
    }
    
    func toggleTask(_ task: Task) {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        if let index = note.tasks.firstIndex(where: { $0.id == task.id }) {
            note.tasks[index].isCompleted.toggle()
            dataManager.saveNote(note, for: dataManager.selectedDate)
        }
    }
    
    func deleteTask(at offsets: IndexSet) {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        note.tasks.remove(atOffsets: offsets)
        dataManager.saveNote(note, for: dataManager.selectedDate)
    }
}

// MARK: - 3. 振り返り画面（KPT + 特別振り返り）
struct ReflectionView: View {
    @ObservedObject var dataManager: AppDataManager
    
    var body: some View {
        let note = dataManager.getNote(for: dataManager.selectedDate)
        
        NavigationView {
            Form {
                Section(header: Text("\(dataManager.dateKey(dataManager.selectedDate)) の振り返り")) {
                    TextEditorView(title: "Keep (継続)", text: Binding(get: { note.keep }, set: { updateNote($0, field: .keep) }))
                    TextEditorView(title: "Problem (課題)", text: Binding(get: { note.problem }, set: { updateNote($0, field: .problem) }))
                    TextEditorView(title: "Try (改善)", text: Binding(get: { note.tryText }, set: { updateNote($0, field: .tryText) }))
                }
                
                // 日曜日なら表示
                if isSunday(dataManager.selectedDate) {
                    Section(header: Text("🌟 今週の振り返り (Weekly)")) {
                        TextEditor(text: Binding(get: { note.weeklyReflection }, set: { updateNote($0, field: .weekly) }))
                            .frame(height: 100)
                    }
                }
                
                // 月末なら表示
                if isLastDayOfMonth(dataManager.selectedDate) {
                    Section(header: Text("🏆 今月の振り返り (Monthly)")) {
                        TextEditor(text: Binding(get: { note.monthlyReflection }, set: { updateNote($0, field: .monthly) }))
                            .frame(height: 100)
                    }
                }
            }
            .navigationTitle("振り返り")
        }
    }
    
    enum Field { case keep, problem, tryText, weekly, monthly }
    func updateNote(_ text: String, field: Field) {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        switch field {
        case .keep: note.keep = text
        case .problem: note.problem = text
        case .tryText: note.tryText = text
        case .weekly: note.weeklyReflection = text
        case .monthly: note.monthlyReflection = text
        }
        dataManager.saveNote(note, for: dataManager.selectedDate)
    }
    
    func isSunday(_ date: Date) -> Bool { Calendar.current.component(.weekday, from: date) == 1 }
    func isLastDayOfMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
        return calendar.component(.month, from: date) != calendar.component(.month, from: nextDay)
    }
}

// MARK: - 4. カレンダー画面（タップ連動）
struct CalendarView: View {
    @ObservedObject var dataManager: AppDataManager
    @Binding var selectedTab: Int
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    
                    // ▼ ここを修正：過去から現在へ向かって並べる ▼
                    ForEach(0..<30) { i in
                        // 今日から「29日前」を起点として、1日ずつ未来（今日）に向かって進める
                        let date = Calendar.current.date(byAdding: .day, value: i - 29, to: Date())!
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: dataManager.selectedDate)
                        
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.blue : Color.green.opacity(0.3))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(Text("\(Calendar.current.component(.day, from: date))").foregroundColor(isSelected ? .white : .primary))
                                .onTapGesture {
                                    dataManager.selectedDate = date
                                    selectedTab = 1 // 振り返りタブへ移動
                                }
                        }
                    }
                    
                }
                .padding()
            }
            .navigationTitle("カレンダー")
        }
    }
}

// 補助的なテキストエディタView
struct TextEditorView: View {
    let title: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.gray)
            TextEditor(text: $text).frame(height: 60)
        }
    }
}
