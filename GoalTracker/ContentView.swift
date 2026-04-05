//
//  ContentView.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/03.
//

import SwiftUI
import Combine

// MARK: - キーボードを閉じるための拡張機能
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: - 1. データモデル
struct DailyNote: Codable {
    var tasks: [Task] = []
    var keep: String = ""
    var problem: String = ""
    var tryList: [String] = []
    var weeklyReflection: String = ""
    var monthlyReflection: String = ""
    var hasAutoPopulated: Bool = false
    var selfRating: Int = 0
}

struct Goal: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    
    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

struct MonthData: Codable {
    var monthlyGoals: [Goal] = []
    var weeklyGoals: [Goal] = []
    var dailyGoals: [Goal] = []
}

struct Task: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool = false
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

// MARK: - 2. データ管理
class AppDataManager: ObservableObject {
    @Published var reflections: [String: DailyNote] = [:]
    @Published var monthConfigs: [String: MonthData] = [:]
    @Published var selectedDate: Date = Date()
    
    private let reflectionsKey = "reflections_storage"
    private let monthConfigsKey = "month_configs_storage"
    
    init() {
        loadFromDisk()
    }
    
    // 🌟 全データをリセットする機能（不整合解消用）
    func resetAllData() {
        UserDefaults.standard.removeObject(forKey: reflectionsKey)
        UserDefaults.standard.removeObject(forKey: monthConfigsKey)
        UserDefaults.standard.synchronize()
        
        self.reflections = [:]
        self.monthConfigs = [:]
        self.objectWillChange.send()
    }
    
    func getNote(for date: Date) -> DailyNote { reflections[dateKey(date)] ?? DailyNote() }
    
    func saveNote(_ note: DailyNote, for date: Date) {
        reflections[dateKey(date)] = note
        persistReflections()
        objectWillChange.send()
    }
    
    func getMonthData(for date: Date) -> MonthData { monthConfigs[monthKey(date)] ?? MonthData() }
    
    func saveMonthData(_ data: MonthData, for date: Date) {
        monthConfigs[monthKey(date)] = data
        persistMonthConfigs()
        objectWillChange.send()
    }

    func getDailyCompletionRate(for date: Date) -> Double {
        let tasks = getNote(for: date).tasks
        guard !tasks.isEmpty else { return 0.0 }
        return Double(tasks.filter { $0.isCompleted }.count) / Double(tasks.count)
    }

    func calculateWeeklyCompositeRate(for sundayDate: Date) -> Double {
        let calendar = Calendar.current
        var weekDates: [Date] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: sundayDate) { weekDates.append(date) }
        }
        let avgDaily = weekDates.map { getDailyCompletionRate(for: $0) }.reduce(0, +) / 7.0
        let selfRate = Double(getNote(for: sundayDate).selfRating) / 5.0
        return selfRate > 0 ? (avgDaily + selfRate) / 2.0 : avgDaily
    }

    func calculateMonthlyCompositeRate(for lastDayOfMonth: Date) -> Double {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: lastDayOfMonth)!
        let components = calendar.dateComponents([.year, .month], from: lastDayOfMonth)
        
        var monthDates: [Date] = []
        var sundays: [Date] = []
        
        for day in 1...range.count {
            var comps = components; comps.day = day
            if let date = calendar.date(from: comps) {
                monthDates.append(date)
                if calendar.component(.weekday, from: date) == 1 { sundays.append(date) }
            }
        }
        
        let avgDaily = monthDates.map { getDailyCompletionRate(for: $0) }.reduce(0, +) / Double(monthDates.count)
        let weeklySelfRates = sundays.map { Double(getNote(for: $0).selfRating) / 5.0 }.filter { $0 > 0 }
        let avgWeeklySelf = weeklySelfRates.isEmpty ? 0 : weeklySelfRates.reduce(0, +) / Double(weeklySelfRates.count)
        let monthlySelf = Double(getNote(for: lastDayOfMonth).selfRating) / 5.0
        
        return monthlySelf > 0 ? (avgDaily + avgWeeklySelf + monthlySelf) / 3.0 : (avgDaily + avgWeeklySelf) / 2.0
    }

    private func persistReflections() {
        if let encoded = try? JSONEncoder().encode(reflections) { UserDefaults.standard.set(encoded, forKey: reflectionsKey) }
    }
    private func persistMonthConfigs() {
        if let encoded = try? JSONEncoder().encode(monthConfigs) { UserDefaults.standard.set(encoded, forKey: monthConfigsKey) }
    }
    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: reflectionsKey), let decoded = try? JSONDecoder().decode([String: DailyNote].self, from: data) { self.reflections = decoded }
        if let data = UserDefaults.standard.data(forKey: monthConfigsKey), let decoded = try? JSONDecoder().decode([String: MonthData].self, from: data) { self.monthConfigs = decoded }
    }

    // 🌟 修正：目標をタスクに「同期」させる（重複は避ける）
    func syncGoalsToTasks(for date: Date) {
        var note = getNote(for: date)
        let monthData = getMonthData(for: date)
        var addedAny = false
        
        // 日次のルーチンをタスクに追加
        for goal in monthData.dailyGoals {
            let taskTitle = "🎯 " + goal.title
            if !note.tasks.contains(where: { $0.title == taskTitle }) {
                note.tasks.append(Task(title: taskTitle))
                addedAny = true
            }
        }
        
        // 昨日のTryをタスクに追加
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        let yesterdayNote = getNote(for: yesterday)
        for tryItem in yesterdayNote.tryList {
            if !tryItem.isEmpty {
                let taskTitle = "🔥 【昨日のTry】" + tryItem
                if !note.tasks.contains(where: { $0.title == taskTitle }) {
                    note.tasks.append(Task(title: taskTitle))
                    addedAny = true
                }
            }
        }
        
        if addedAny {
            saveNote(note, for: date)
        }
    }

    func dateKey(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
    func monthKey(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f.string(from: date) }
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
        .onTapGesture {
            hideKeyboard() // 画面余白タップでキーボードを閉じる
        }
    }
}

// MARK: - 4. ホーム画面
struct HomeView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var newTaskTitle = ""
    @State private var showResetAlert = false //これを消す##################################
    
    var body: some View {
        let currentNote = dataManager.getNote(for: dataManager.selectedDate)
        NavigationView {
            VStack {
                Text(dataManager.dateKey(dataManager.selectedDate)).font(.caption).foregroundColor(.gray)
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
                // 画面表示時に目標を同期
                dataManager.syncGoalsToTasks(for: dataManager.selectedDate)
            }
            .onChange(of: dataManager.selectedDate) { _, newDate in
                // 日付変更時にも目標を同期
                dataManager.syncGoalsToTasks(for: newDate)
            }
            .toolbar {
                // 開発用リセットボタン　ここから＃＃＃＃＃＃＃＃＃＃＃＃＃＃＃
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showResetAlert = true }) {
                        Image(systemName: "trash").foregroundColor(.red)
                    }
                }
                //ここまで消す
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { hideKeyboard() }
                }
            }
            //ここから################################################
            .alert("全データをリセット", isPresented: $showResetAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("削除する", role: .destructive) {
                    dataManager.resetAllData()
                }
            } message: {
                Text("保存されているすべてのタスク・目標・振り返りデータが消去されます。本当によろしいですか？")
            }
            //ここまで#################################################################
        }
    }
    func addTask() {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        if !newTaskTitle.isEmpty { note.tasks.append(Task(title: newTaskTitle)); dataManager.saveNote(note, for: dataManager.selectedDate); newTaskTitle = "" }
    }
    func toggleTask(_ task: Task) {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        if let i = note.tasks.firstIndex(where: { $0.id == task.id }) { note.tasks[i].isCompleted.toggle(); dataManager.saveNote(note, for: dataManager.selectedDate) }
    }
    func deleteTask(at offsets: IndexSet) {
        var note = dataManager.getNote(for: dataManager.selectedDate); note.tasks.remove(atOffsets: offsets); dataManager.saveNote(note, for: dataManager.selectedDate)
    }
}

// MARK: - 5. 振り返り画面
struct ReflectionView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var reflectionType = 0
    
    private var isSunday: Bool { Calendar.current.component(.weekday, from: dataManager.selectedDate) == 1 }
    private var isLastDayOfMonth: Bool {
        let cal = Calendar.current; let date = dataManager.selectedDate; let nextDay = cal.date(byAdding: .day, value: 1, to: date)!
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
                .pickerStyle(SegmentedPickerStyle()).padding()
                .onChange(of: dataManager.selectedDate) { _, _ in reflectionType = 0 }

                if reflectionType == 0 {
                    AchievementCard(title: "今日のタスク完了率", rate: dataManager.getDailyCompletionRate(for: dataManager.selectedDate), showStars: false, selfRating: .constant(0))
                } else if reflectionType == 1 {
                    AchievementCard(title: "週次・複合達成度", rate: dataManager.calculateWeeklyCompositeRate(for: dataManager.selectedDate), showStars: true, selfRating: Binding(get: { note.selfRating }, set: { updateSelfRating($0) }))
                } else {
                    AchievementCard(title: "月次・複合達成度", rate: dataManager.calculateMonthlyCompositeRate(for: dataManager.selectedDate), showStars: true, selfRating: Binding(get: { note.selfRating }, set: { updateSelfRating($0) }))
                }

                Form {
                    if reflectionType == 0 {
                        Section(header: Text("KPT振り返り")) {
                            TextEditorView(title: "Keep", text: Binding(get: { note.keep }, set: { updateNote($0, field: .keep) }))
                            TextEditorView(title: "Problem", text: Binding(get: { note.problem }, set: { updateNote($0, field: .problem) }))
                            BulletInputSection(title: "Try (翌日タスク化)", items: note.tryList) { newList in
                                var updatedNote = note; updatedNote.tryList = newList; dataManager.saveNote(updatedNote, for: dataManager.selectedDate)
                            }
                        }
                    } else if reflectionType == 1 {
                        Section(header: Text("週次振り返り")) { TextEditorView(title: "今週のまとめ", text: Binding(get: { note.weeklyReflection }, set: { updateNote($0, field: .weekly) }), minHeight: 100) }
                    } else {
                        Section(header: Text("月次振り返り")) { TextEditorView(title: "今月のまとめ", text: Binding(get: { note.monthlyReflection }, set: { updateNote($0, field: .monthly) }), minHeight: 100) }
                    }
                }
            }
            .navigationTitle("振り返り")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { hideKeyboard() }
                }
            }
        }
    }
    func updateSelfRating(_ rating: Int) { var note = dataManager.getNote(for: dataManager.selectedDate); note.selfRating = rating; dataManager.saveNote(note, for: dataManager.selectedDate) }
    enum Field { case keep, problem, weekly, monthly }
    func updateNote(_ text: String, field: Field) {
        var note = dataManager.getNote(for: dataManager.selectedDate)
        switch field { case .keep: note.keep = text; case .problem: note.problem = text; case .weekly: note.weeklyReflection = text; case .monthly: note.monthlyReflection = text }
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
        let weeklyRate = dataManager.calculateWeeklyCompositeRate(for: Date())
        let monthlyRate = dataManager.calculateMonthlyCompositeRate(for: Date())
        
        let prevMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate)!
        let prevMonthData = dataManager.getMonthData(for: prevMonthDate)
        
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    HStack(spacing: 15) {
                        SummaryCard(title: "今週の達成度", rate: weeklyRate, color: .orange)
                        SummaryCard(title: "今月の達成度", rate: monthlyRate, color: .blue)
                    }.padding(.horizontal)

                    HStack {
                        Button(action: { changeMonth(-1) }) { Image(systemName: "chevron.left") }
                        Spacer(); Text(monthString(calendarDisplayDate)).font(.headline); Spacer()
                        Button(action: { changeMonth(1) }) { Image(systemName: "chevron.right") }
                    }.padding(.horizontal)

                    VStack(spacing: 10) {
                        GoalListSection(title: "🏆 今月の目標", goals: monthData.monthlyGoals, onUpdate: { updateGoals($0, field: .monthly) }) {
                            copyPreviousGoals(prevGoals: prevMonthData.monthlyGoals, field: .monthly)
                        }
                        GoalListSection(title: "📅 週次の目標", goals: monthData.weeklyGoals, onUpdate: { updateGoals($0, field: .weekly) }) {
                            copyPreviousGoals(prevGoals: prevMonthData.weeklyGoals, field: .weekly)
                        }
                        GoalListSection(title: "🎯 日次の目標", goals: monthData.dailyGoals, onUpdate: { updateGoals($0, field: .daily) }) {
                            copyPreviousGoals(prevGoals: prevMonthData.dailyGoals, field: .daily)
                        }
                    }.padding(.horizontal)

                    CalendarGridView(dataManager: dataManager, displayDate: calendarDisplayDate, selectedDate: $dataManager.selectedDate, selectedTab: $selectedTab)
                }
            }
            .navigationTitle("カレンダー")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { hideKeyboard() }
                }
            }
        }
    }
    func changeMonth(_ val: Int) { calendarDisplayDate = Calendar.current.date(byAdding: .month, value: val, to: calendarDisplayDate)! }
    func monthString(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy年 M月"; return f.string(from: date) }
    
    enum Field { case monthly, weekly, daily }
    
    func updateGoals(_ newGoals: [Goal], field: Field) {
        var data = dataManager.getMonthData(for: calendarDisplayDate)
        switch field { case .monthly: data.monthlyGoals = newGoals; case .weekly: data.weeklyGoals = newGoals; case .daily: data.dailyGoals = newGoals }
        dataManager.saveMonthData(data, for: calendarDisplayDate)
        // 目標更新時に、即座に選択中の日付のタスクに同期させる
        dataManager.syncGoalsToTasks(for: dataManager.selectedDate)
    }
    
    func copyPreviousGoals(prevGoals: [Goal], field: Field) {
        let data = dataManager.getMonthData(for: calendarDisplayDate)
        var currentGoals: [Goal]
        switch field {
            case .monthly: currentGoals = data.monthlyGoals
            case .weekly: currentGoals = data.weeklyGoals
            case .daily: currentGoals = data.dailyGoals
        }
        
        let newTitles = currentGoals.map { $0.title }
        for goal in prevGoals {
            if !newTitles.contains(goal.title) {
                currentGoals.append(Goal(title: goal.title))
            }
        }
        updateGoals(currentGoals, field: field)
    }
}

// MARK: - 補助コンポーネント

struct AchievementCard: View {
    let title: String; let rate: Double; let showStars: Bool; @Binding var selfRating: Int
    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            HStack {
                VStack(alignment: .leading) {
                    Text("\(Int(rate * 100))%").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundColor(.blue)
                    Text(showStars ? "（自動＋評価の平均）" : "（自動計算のみ）").font(.caption2).foregroundColor(.gray)
                }
                Spacer()
                if showStars {
                    VStack(alignment: .trailing) {
                        Text("自己評価").font(.caption).foregroundColor(.gray)
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= selfRating ? "star.fill" : "star").foregroundColor(i <= selfRating ? .orange : .gray).onTapGesture { selfRating = i }
                            }
                        }
                    }
                }
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(15).shadow(radius: 2).padding(.horizontal)
    }
}

struct SummaryCard: View {
    let title: String; let rate: Double; let color: Color
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.secondary)
            HStack {
                Text("\(Int(rate * 100))%").font(.title2).bold().foregroundColor(color)
                Spacer()
                ZStack { Circle().stroke(color.opacity(0.2), lineWidth: 4); Circle().trim(from: 0, to: rate).stroke(color, lineWidth: 4).rotationEffect(.degrees(-90)) }.frame(width: 30, height: 30)
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

struct GoalListSection: View {
    let title: String; var goals: [Goal]; var onUpdate: ([Goal]) -> Void
    var onCopyPrevious: (() -> Void)? = nil
    
    @State private var tempGoal = ""; @State private var showAddAlert = false
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.caption).bold().foregroundColor(.blue)
                Spacer()
                if let onCopyPrevious = onCopyPrevious {
                    Button(action: onCopyPrevious) {
                        Image(systemName: "doc.on.clipboard").font(.system(size: 14)).foregroundColor(.gray)
                    }
                    .padding(.trailing, 8)
                }
                Button(action: { showAddAlert = true }) { Image(systemName: "plus").font(.system(size: 14, weight: .bold)) }
            }
            ForEach(goals.indices, id: \.self) { i in
                HStack { Text("・").foregroundColor(.blue); Text(goals[i].title).font(.subheadline); Spacer()
                    Button(action: { var new = goals; new.remove(at: i); onUpdate(new) }) { Image(systemName: "xmark.circle").foregroundColor(.gray) }
                }
            }
        }.padding(10).background(Color.white).cornerRadius(8).shadow(radius: 1)
        .alert("目標を追加", isPresented: $showAddAlert) {
            TextField("新しい目標", text: $tempGoal); Button("キャンセル", role: .cancel) { tempGoal = "" }
            Button("追加") { if !tempGoal.isEmpty { var new = goals; new.append(Goal(title: tempGoal)); onUpdate(new); tempGoal = "" } }
        }
    }
}

struct CalendarGridView: View {
    @ObservedObject var dataManager: AppDataManager; let displayDate: Date; @Binding var selectedDate: Date; @Binding var selectedTab: Int
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    var body: some View {
        let days = generateDays(); let today = Calendar.current.startOfDay(for: Date())
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<days.count, id: \.self) { i in
                if let date = days[i] {
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate); let isFuture = date > today
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isFuture ? Color(.systemGray6) : getHeatmapColor(for: date))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: isSelected ? 3 : 0)
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.caption)
                                    .foregroundColor(isFuture ? .gray : (shouldTextBeWhite(for: date) ? .white : .primary)))
                        .onTapGesture {
                            if !isFuture {
                                selectedDate = date
                                selectedTab = 1
                            }
                        }
                } else { Color.clear }
            }
        }.padding()
    }
    private func getHeatmapColor(for date: Date) -> Color {
        let rate = dataManager.getDailyCompletionRate(for: date)
        if rate == 0 { return dataManager.getNote(for: date).tasks.isEmpty ? Color(.systemGray6) : Color.green.opacity(0.1) }
        switch rate { case ..<0.25: return Color.green.opacity(0.25); case 0.25..<0.5: return Color.green.opacity(0.5); case 0.5..<0.75: return Color.green.opacity(0.7); case 0.75..<1.0: return Color.green.opacity(0.85); case 1.0: return Color.green; default: return Color(.systemGray6) }
    }
    private func shouldTextBeWhite(for date: Date) -> Bool { dataManager.getDailyCompletionRate(for: date) >= 0.75 }
    func generateDays() -> [Date?] {
        let cal = Calendar.current; let start = cal.date(from: cal.dateComponents([.year, .month], from: displayDate))!; let range = cal.range(of: .day, in: .month, for: start)!; let firstDay = cal.component(.weekday, from: start)
        var days: [Date?] = Array(repeating: nil, count: firstDay - 1)
        for i in 0..<range.count { days.append(cal.date(byAdding: .day, value: i, to: start)!) }; return days
    }
}

struct BulletInputSection: View {
    let title: String; var items: [String]; var onUpdate: ([String]) -> Void
    @State private var tempItem = ""; @State private var showAddAlert = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.caption).foregroundColor(.gray); Spacer(); Button(action: { showAddAlert = true }) { Image(systemName: "plus.circle.fill") } }
            ForEach(items.indices, id: \.self) { i in
                HStack { Text("・").foregroundColor(.blue); Text(items[i]).font(.body); Spacer(); Button(action: { var new = items; new.remove(at: i); onUpdate(new) }) { Image(systemName: "xmark.circle").foregroundColor(.gray) } }
            }
        }.alert("Tryを追加", isPresented: $showAddAlert) {
            TextField("タスク名", text: $tempItem); Button("追加") { if !tempItem.isEmpty { var new = items; new.append(tempItem); onUpdate(new); tempItem = "" } }; Button("キャンセル", role: .cancel) { tempItem = "" }
        }
    }
}

struct TextEditorView: View {
    let title: String; @Binding var text: String; var minHeight: CGFloat = 60
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.gray)
            TextField("入力してください...", text: $text, axis: .vertical)
                .lineLimit(4...15)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .frame(minHeight: minHeight, alignment: .top)
        }
        .padding(.vertical, 4)
    }
}

#Preview { ContentView() }
