//
//  ContentView.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/03.
//

import SwiftUI
import Combine

// MARK: - データモデル
struct DailyNote {
    var tasks: [Task] = []
    var keep: String = ""
    var problem: String = ""
    var tryText: String = ""
    var weeklyReflection: String = ""
    var monthlyReflection: String = ""
    var hasAutoPopulated: Bool = false
}

// 月ごとの目標を「列（配列）」で保存するように変更
struct MonthData {
    var monthlyGoals: [String] = []
    var weeklyGoals: [String] = []
    var dailyGoals: [String] = []
}

struct Task: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// MARK: - データ管理
class AppDataManager: ObservableObject {
    @Published var reflections: [String: DailyNote] = [:]
    @Published var monthConfigs: [String: MonthData] = [:]
    @Published var selectedDate: Date = Date()
    
    func getNote(for date: Date) -> DailyNote { reflections[dateKey(date)] ?? DailyNote() }
    func saveNote(_ note: DailyNote, for date: Date) { reflections[dateKey(date)] = note }
    
    func getMonthData(for date: Date) -> MonthData { monthConfigs[monthKey(date)] ?? MonthData() }
    func saveMonthData(_ data: MonthData, for date: Date) { monthConfigs[monthKey(date)] = data }
    
    // 自動入力機能：複数の「日次目標」と「昨日のTry」をすべてタスク化
    func prepareDailyTasksIfNeeded(for date: Date) {
        var note = getNote(for: date)
        if note.hasAutoPopulated { return }
        
        let monthData = getMonthData(for: date)
        
        // ① 複数の「日次目標」をすべて追加
        for goal in monthData.dailyGoals {
            note.tasks.append(Task(title: "🎯 " + goal))
        }
        
        // ② 前日の「Try」があれば追加
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        let yesterdayNote = getNote(for: yesterday)
        if !yesterdayNote.tryText.isEmpty {
            note.tasks.append(Task(title: "🔥 【昨日のTry】" + yesterdayNote.tryText))
        }
        
        note.hasAutoPopulated = true
        saveNote(note, for: date)
    }
    
    func dateKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    func monthKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f.string(from: date)
    }
}

// MARK: - 1. アプリ全体
struct ContentView: View {
    @StateObject private var dataManager = AppDataManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(dataManager: dataManager)
                .tabItem { Image(systemName: "house"); Text("ホーム") }.tag(0)
            ReflectionView(dataManager: dataManager)
                .tabItem { Image(systemName: "square.and.pencil"); Text("振り返り") }.tag(1)
            CalendarView(dataManager: dataManager, selectedTab: $selectedTab)
                .tabItem { Image(systemName: "calendar"); Text("カレンダー") }.tag(2)
        }
    }
}

// MARK: - 2. ホーム画面（自動入力対応）
struct HomeView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var newTaskTitle = ""
    
    var body: some View {
        let currentNote = dataManager.getNote(for: dataManager.selectedDate)
        NavigationView {
            VStack {
                Text(dataManager.dateKey(dataManager.selectedDate) + " のタスク").font(.caption).foregroundColor(.gray)
                HStack {
                    TextField("新しいタスク...", text: $newTaskTitle).textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: addTask) { Image(systemName: "plus.circle.fill").font(.title) }
                }.padding()
                List {
                    Section {
                        ForEach(currentNote.tasks) { task in
                            HStack {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(task.isCompleted ? .green : .gray)
                                Text(task.title).strikethrough(task.isCompleted)
                            }.onTapGesture { toggleTask(task) }
                        }.onDelete(perform: deleteTask)
                    }
                }
            }
            .navigationTitle("今日のタスク")
            .onAppear { dataManager.prepareDailyTasksIfNeeded(for: dataManager.selectedDate) }
        }
    }
    func addTask() {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        if !newTaskTitle.isEmpty {
            note.tasks.append(Task(title: newTaskTitle))
            dataManager.saveNote(note, for: dataManager.selectedDate); newTaskTitle = ""
        }
    }
    func toggleTask(_ task: Task) {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        if let i = note.tasks.firstIndex(where: { $0.id == task.id }) {
            note.tasks[i].isCompleted.toggle(); dataManager.saveNote(note, for: dataManager.selectedDate)
        }
    }
    func deleteTask(at offsets: IndexSet) {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        note.tasks.remove(atOffsets: offsets); dataManager.saveNote(note, for: dataManager.selectedDate)
    }
}

// MARK: - 3. 振り返り画面
struct ReflectionView: View {
    @ObservedObject var dataManager: AppDataManager
    var body: some View {
        let note = dataManager.getNote(for: dataManager.selectedDate)
        NavigationView {
            Form {
                Section(header: Text("KPT振り返り")) {
                    TextEditorView(title: "Keep", text: Binding(get: { note.keep }, set: { updateNote($0, field: .keep) }))
                    TextEditorView(title: "Problem", text: Binding(get: { note.problem }, set: { updateNote($0, field: .problem) }))
                    TextEditorView(title: "Try", text: Binding(get: { note.tryText }, set: { updateNote($0, field: .tryText) }))
                }
            }.navigationTitle("振り返り")
        }
    }
    enum Field { case keep, problem, tryText }
    func updateNote(_ text: String, field: Field) {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        switch field { case .keep: note.keep = text; case .problem: note.problem = text; case .tryText: note.tryText = text }
        dataManager.saveNote(note, for: dataManager.selectedDate)
    }
}

// MARK: - 4. カレンダー画面（複数目標対応）
struct CalendarView: View {
    @ObservedObject var dataManager: AppDataManager
    @Binding var selectedTab: Int
    @State private var calendarDisplayDate = Date()
    
    var body: some View {
        let monthData = dataManager.getMonthData(for: calendarDisplayDate)
        
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    // 月切り替え
                    HStack {
                        Button(action: { changeMonth(-1) }) { Image(systemName: "chevron.left") }
                        Spacer(); Text(monthString(calendarDisplayDate)).font(.headline); Spacer()
                        Button(action: { changeMonth(1) }) { Image(systemName: "chevron.right") }
                    }.padding()

                    // 複数目標入力セクション
                    VStack(spacing: 10) {
                        GoalListSection(title: "🏆 今月の目標", goals: monthData.monthlyGoals) { updateGoals($0, field: .monthly) }
                        GoalListSection(title: "📅 今週の目標", goals: monthData.weeklyGoals) { updateGoals($0, field: .weekly) }
                        GoalListSection(title: "🎯 日次のルーチン", goals: monthData.dailyGoals) { updateGoals($0, field: .daily) }
                    }.padding(.horizontal)

                    // カレンダー
                    CalendarGridView(displayDate: calendarDisplayDate, selectedDate: $dataManager.selectedDate, selectedTab: $selectedTab)
                }
            }.navigationTitle("カレンダー")
        }
    }
    
    func changeMonth(_ val: Int) { calendarDisplayDate = Calendar.current.date(byAdding: .month, value: val, to: calendarDisplayDate)! }
    func monthString(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy年 M月"; return f.string(from: date) }
    
    enum Field { case monthly, weekly, daily }
    func updateGoals(_ newGoals: [String], field: Field) {
        var data = dataManager.getMonthData(for: calendarDisplayDate)
        switch field { case .monthly: data.monthlyGoals = newGoals; case .weekly: data.weeklyGoals = newGoals; case .daily: data.dailyGoals = newGoals }
        dataManager.saveMonthData(data, for: calendarDisplayDate)
    }
}

// 複数の目標を管理するための補助パーツ
struct GoalListSection: View {
    let title: String
    var goals: [String]
    var onUpdate: ([String]) -> Void
    @State private var tempGoal = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).bold().foregroundColor(.blue)
            ForEach(goals.indices, id: \.self) { i in
                HStack {
                    Text("・" + goals[i]).font(.subheadline)
                    Spacer()
                    Button(action: { removeGoal(at: i) }) { Image(systemName: "xmark.circle").foregroundColor(.gray) }
                }
            }
            HStack {
                TextField("追加...", text: $tempGoal).textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: addGoal) { Image(systemName: "plus.circle.fill") }
            }
        }
        .padding(10).background(Color.white).cornerRadius(8).shadow(radius: 1)
    }
    func addGoal() { if !tempGoal.isEmpty { var new = goals; new.append(tempGoal); onUpdate(new); tempGoal = "" } }
    func removeGoal(at index: Int) { var new = goals; new.remove(at: index); onUpdate(new) }
}

// カレンダーのマス目部分
struct CalendarGridView: View {
    let displayDate: Date
    @Binding var selectedDate: Date
    @Binding var selectedTab: Int
    let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        let days = generateDays()
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<days.count, id: \.self) { i in
                if let date = days[i] {
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue : Color.green.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Text("\(Calendar.current.component(.day, from: date))").font(.caption).foregroundColor(isSelected ? .white : .primary))
                        .onTapGesture { selectedDate = date; selectedTab = 0 }
                } else { Color.clear }
            }
        }
        .padding()
    }
    
    func generateDays() -> [Date?] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: displayDate))!
        let range = cal.range(of: .day, in: .month, for: start)!
        let firstDay = cal.component(.weekday, from: start)
        var days: [Date?] = Array(repeating: nil, count: firstDay - 1)
        for i in 0..<range.count { days.append(cal.date(byAdding: .day, value: i, to: start)!) }
        return days
    }
}

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
