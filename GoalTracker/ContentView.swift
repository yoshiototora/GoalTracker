//
//  ContentView.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/03.
//

import SwiftUI
import Combine

// MARK: - 1. データモデル
struct DailyNote {
    var tasks: [Task] = []
    var keep: String = ""
    var problem: String = ""
    var tryList: [String] = []
    var weeklyReflection: String = ""
    var monthlyReflection: String = ""
    var hasAutoPopulated: Bool = false
}

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

// MARK: - 2. データ管理
class AppDataManager: ObservableObject {
    @Published var reflections: [String: DailyNote] = [:]
    @Published var monthConfigs: [String: MonthData] = [:]
    @Published var selectedDate: Date = Date()
    
    func getNote(for date: Date) -> DailyNote { reflections[dateKey(date)] ?? DailyNote() }
    func saveNote(_ note: DailyNote, for date: Date) {
        reflections[dateKey(date)] = note
        objectWillChange.send()
    }
    
    func getMonthData(for date: Date) -> MonthData { monthConfigs[monthKey(date)] ?? MonthData() }
    func saveMonthData(_ data: MonthData, for date: Date) {
        monthConfigs[monthKey(date)] = data
        objectWillChange.send()
    }
    
    func prepareDailyTasksIfNeeded(for date: Date) {
        var note = getNote(for: date)
        if note.hasAutoPopulated || !note.tasks.isEmpty { return }
        
        let monthData = getMonthData(for: date)
        for goal in monthData.dailyGoals {
            note.tasks.append(Task(title: "🎯 " + goal))
        }
        
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        let yesterdayNote = getNote(for: yesterday)
        
        for tryItem in yesterdayNote.tryList {
            if !tryItem.isEmpty {
                note.tasks.append(Task(title: "🔥 【昨日のTry】" + tryItem))
            }
        }
        
        if !note.tasks.isEmpty {
            note.hasAutoPopulated = true
            saveNote(note, for: date)
        }
    }
    
    func dateKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    func monthKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f.string(from: date)
    }
}

// MARK: - 3. メイン画面
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

// MARK: - 4. ホーム画面
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
            .id(dataManager.selectedDate)
            .onAppear {
                dataManager.prepareDailyTasksIfNeeded(for: dataManager.selectedDate)
            }
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

// MARK: - 5. 振り返り画面 (iOS 17+ 修正版)
struct ReflectionView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var reflectionType = 0
    
    private var isSunday: Bool { Calendar.current.component(.weekday, from: dataManager.selectedDate) == 1 }
    private var isLastDayOfMonth: Bool {
        let cal = Calendar.current
        let date = dataManager.selectedDate
        let nextDay = cal.date(byAdding: .day, value: 1, to: date)!
        return cal.component(.month, from: date) != cal.component(.month, from: nextDay)
    }
    
    var body: some View {
        let note = dataManager.getNote(for: dataManager.selectedDate)
        
        NavigationView {
            VStack {
                Picker("振り返り", selection: $reflectionType) {
                    Text("日次").tag(0)
                    if isSunday { Text("週次").tag(1) }
                    if isLastDayOfMonth { Text("月次").tag(2) }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                // ★ ここを iOS 17 以降の書き方に修正
                .onChange(of: dataManager.selectedDate) { oldDate, newDate in
                    reflectionType = 0
                }

                Form {
                    if reflectionType == 0 {
                        Section(header: Text("KPT振り返り (日次)")) {
                            TextEditorView(title: "Keep", text: Binding(get: { note.keep }, set: { updateNote($0, field: .keep) }))
                            TextEditorView(title: "Problem", text: Binding(get: { note.problem }, set: { updateNote($0, field: .problem) }))
                            
                            BulletInputSection(title: "Try (箇条書き・翌日タスク化)", items: note.tryList) { newList in
                                var updatedNote = note
                                updatedNote.tryList = newList
                                dataManager.saveNote(updatedNote, for: dataManager.selectedDate)
                            }
                        }
                    } else if reflectionType == 1 && isSunday {
                        Section(header: Text("週の振り返り")) {
                            TextEditorView(title: "今週の振り返り", text: Binding(get: { note.weeklyReflection }, set: { updateNote($0, field: .weekly) }), minHeight: 200)
                        }
                    } else if reflectionType == 2 && isLastDayOfMonth {
                        Section(header: Text("月の振り返り")) {
                            TextEditorView(title: "今月の振り返り", text: Binding(get: { note.monthlyReflection }, set: { updateNote($0, field: .monthly) }), minHeight: 200)
                        }
                    }
                }
            }
            .navigationTitle("振り返り")
        }
    }
    
    enum Field { case keep, problem, weekly, monthly }
    func updateNote(_ text: String, field: Field) {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        switch field {
        case .keep: note.keep = text
        case .problem: note.problem = text
        case .weekly: note.weeklyReflection = text
        case .monthly: note.monthlyReflection = text
        }
        dataManager.saveNote(note, for: dataManager.selectedDate)
    }
}

// MARK: - 6. カレンダー画面
struct CalendarView: View {
    @ObservedObject var dataManager: AppDataManager
    @Binding var selectedTab: Int
    @State private var calendarDisplayDate = Date()
    
    var body: some View {
        let monthData = dataManager.getMonthData(for: calendarDisplayDate)
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    HStack {
                        Button(action: { changeMonth(-1) }) { Image(systemName: "chevron.left") }
                        Spacer(); Text(monthString(calendarDisplayDate)).font(.headline); Spacer()
                        Button(action: { changeMonth(1) }) { Image(systemName: "chevron.right") }
                    }.padding()

                    VStack(spacing: 10) {
                        GoalListSection(title: "🏆 今月の目標", goals: monthData.monthlyGoals) { updateGoals($0, field: .monthly) }
                        GoalListSection(title: "📅 今週の目標", goals: monthData.weeklyGoals) { updateGoals($0, field: .weekly) }
                        GoalListSection(title: "🎯 日次のルーチン", goals: monthData.dailyGoals) { updateGoals($0, field: .daily) }
                    }.padding(.horizontal)

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

// MARK: - 共通補助パーツ

struct BulletInputSection: View {
    let title: String
    var items: [String]
    var onUpdate: ([String]) -> Void
    @State private var tempItem = ""
    @State private var showAddAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.caption).foregroundColor(.gray)
                Spacer()
                Button(action: { showAddAlert = true }) {
                    Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                }
            }
            ForEach(items.indices, id: \.self) { i in
                HStack {
                    Text("・").foregroundColor(.blue)
                    Text(items[i]).font(.body)
                    Spacer()
                    Button(action: {
                        var new = items
                        new.remove(at: i)
                        onUpdate(new)
                    }) { Image(systemName: "xmark.circle").foregroundColor(.gray) }
                }
            }
        }
        .padding(.vertical, 5)
        .alert("Tryを追加", isPresented: $showAddAlert) {
            TextField("次の日のタスクになります", text: $tempItem)
            Button("キャンセル", role: .cancel) { tempItem = "" }
            Button("追加") {
                if !tempItem.isEmpty {
                    var new = items
                    new.append(tempItem)
                    onUpdate(new)
                    tempItem = ""
                }
            }
        }
    }
}

struct GoalListSection: View {
    let title: String
    var goals: [String]
    var onUpdate: ([String]) -> Void
    @State private var tempGoal = ""
    @State private var showAddAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.caption).bold().foregroundColor(.blue)
                Spacer()
                Button(action: { showAddAlert = true }) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundColor(.blue)
                }
            }
            ForEach(goals.indices, id: \.self) { i in
                HStack {
                    Text("・" + goals[i]).font(.subheadline)
                    Spacer()
                    Button(action: {
                        var new = goals
                        new.remove(at: i)
                        onUpdate(new)
                    }) { Image(systemName: "xmark.circle").foregroundColor(.gray) }
                }
            }
        }
        .padding(10).background(Color.white).cornerRadius(8).shadow(radius: 1)
        .alert("目標を追加", isPresented: $showAddAlert) {
            TextField("新しい目標", text: $tempGoal)
            Button("キャンセル", role: .cancel) { tempGoal = "" }
            Button("追加") {
                if !tempGoal.isEmpty {
                    var new = goals
                    new.append(tempGoal)
                    onUpdate(new)
                    tempGoal = ""
                }
            }
        }
    }
}

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
    var minHeight: CGFloat = 60
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.gray)
            TextEditor(text: $text).frame(minHeight: minHeight)
        }
    }
}
