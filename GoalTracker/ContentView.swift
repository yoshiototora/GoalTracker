//
//  ContentView.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/03.
//

import SwiftUI
import Combine
import UserNotifications

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
}

struct Goal: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

struct WeekData: Codable {
    var goals: [Goal] = []
    var reflection: String = ""
}

struct MonthData: Codable {
    var monthlyGoals: [Goal] = []
    var weeklyGoals: [Goal] = []
    var dailyGoals: [Goal] = []
    var reflection: String = ""
    
    enum CodingKeys: String, CodingKey {
        case monthlyGoals, weeklyGoals, dailyGoals, reflection
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monthlyGoals = try container.decodeIfPresent([Goal].self, forKey: .monthlyGoals) ?? []
        weeklyGoals = try container.decodeIfPresent([Goal].self, forKey: .weeklyGoals) ?? []
        dailyGoals = try container.decodeIfPresent([Goal].self, forKey: .dailyGoals) ?? []
        reflection = try container.decodeIfPresent(String.self, forKey: .reflection) ?? ""
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monthlyGoals, forKey: .monthlyGoals)
        try container.encode(weeklyGoals, forKey: .weeklyGoals)
        try container.encode(dailyGoals, forKey: .dailyGoals)
        try container.encode(reflection, forKey: .reflection)
    }
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

struct AppSettings: Codable {
    var goalNotificationEnabled: Bool = false
    var goalNotificationTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    
    var reflectionNotificationEnabled: Bool = false
    var reflectionNotificationTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
}

// MARK: - 2. データ管理
class AppDataManager: ObservableObject {
    @Published var reflections: [String: DailyNote] = [:]
    @Published var weekConfigs: [String: WeekData] = [:]
    @Published var monthConfigs: [String: MonthData] = [:]
    @Published var selectedDate: Date = Date()
    @Published var appSettings: AppSettings = AppSettings()
    
    private let reflectionsKey = "reflections_storage"
    private let weekConfigsKey = "week_configs_storage"
    private let monthConfigsKey = "month_configs_storage"
    private let settingsKey = "app_settings_storage"
    
    private static let ymdFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }()
    private static let ymFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f }()
    private static let titleDailyFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy年M月d日"; return f }()
    private static let titleWeeklyFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "M/d"; return f }()
    private static let titleMonthlyFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy年M月"; return f }()
    
    init() { loadFromDisk() }
    
    func resetAllData() {
        UserDefaults.standard.removeObject(forKey: reflectionsKey)
        UserDefaults.standard.removeObject(forKey: weekConfigsKey)
        UserDefaults.standard.removeObject(forKey: monthConfigsKey)
        self.reflections = [:]
        self.weekConfigs = [:]
        self.monthConfigs = [:]
    }
    
    func getNote(for date: Date) -> DailyNote { reflections[dateKey(date)] ?? DailyNote() }
    func saveNote(_ note: DailyNote, for date: Date) { reflections[dateKey(date)] = note; persistData() }
    
    func getWeekData(for date: Date) -> WeekData { weekConfigs[weekKey(date)] ?? WeekData() }
    func saveWeekData(_ data: WeekData, for date: Date) { weekConfigs[weekKey(date)] = data; persistData() }
    
    func getMonthData(for date: Date) -> MonthData { monthConfigs[monthKey(date)] ?? MonthData() }
    func saveMonthData(_ data: MonthData, for date: Date) { monthConfigs[monthKey(date)] = data; persistData() }

    func getCustomWeekInfo(for date: Date) -> (key: String, dates: [Date]) {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let comps = DateComponents(year: year, month: month)
        guard let startOfMonth = cal.date(from: comps),
              let daysInMonth = cal.range(of: .day, in: .month, for: startOfMonth)?.count else { return ("", []) }
        
        var currentWeekDates: [Date] = []
        var currentWeekNumber = 1
        var targetWeekNumber = 1
        var targetWeekDates: [Date] = []
        
        for dayOffset in 0..<daysInMonth {
            let currentDate = cal.date(byAdding: .day, value: dayOffset, to: startOfMonth)!
            currentWeekDates.append(currentDate)
            if cal.isDate(currentDate, inSameDayAs: date) { targetWeekNumber = currentWeekNumber }
            if cal.component(.weekday, from: currentDate) == 1 || dayOffset == daysInMonth - 1 {
                if targetWeekNumber == currentWeekNumber { targetWeekDates = currentWeekDates }
                currentWeekNumber += 1
                currentWeekDates = []
            }
        }
        return (String(format: "%04d-%02d-W%d", year, month, targetWeekNumber), targetWeekDates)
    }

    func getDailyCompletionRate(for date: Date) -> Double {
        let tasks = getNote(for: date).tasks
        guard !tasks.isEmpty else { return 0.0 }
        return Double(tasks.filter { $0.isCompleted }.count) / Double(tasks.count)
    }

    func getWeeklyDailyAvgRate(for date: Date) -> Double {
        let dates = getCustomWeekInfo(for: date).dates
        guard !dates.isEmpty else { return 0 }
        return dates.map { getDailyCompletionRate(for: $0) }.reduce(0, +) / Double(dates.count)
    }
    
    func getWeeklyGoalRate(for date: Date) -> Double {
        let goals = getWeekData(for: date).goals
        guard !goals.isEmpty else { return 0.0 }
        return Double(goals.filter { $0.isCompleted }.count) / Double(goals.count)
    }

    func getMonthlyDailyAvgRate(for date: Date) -> Double {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: date),
              let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: date)) else { return 0 }
        let sum = (0..<range.count).compactMap { cal.date(byAdding: .day, value: $0, to: startOfMonth) }.map { getDailyCompletionRate(for: $0) }.reduce(0, +)
        return sum / Double(range.count)
    }

    func getMonthlyWeeklyGoalAvgRate(for date: Date) -> Double {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: date),
              let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: date)) else { return 0 }
        var weekKeysInMonth = Set<String>()
        for i in 0..<range.count {
            if let d = cal.date(byAdding: .day, value: i, to: startOfMonth) { weekKeysInMonth.insert(weekKey(d)) }
        }
        let rates = weekKeysInMonth.map { key in
            let goals = weekConfigs[key]?.goals ?? []
            return goals.isEmpty ? 0.0 : Double(goals.filter { $0.isCompleted }.count) / Double(goals.count)
        }
        return rates.isEmpty ? 0 : rates.reduce(0, +) / Double(rates.count)
    }

    func getMonthlyGoalRate(for date: Date) -> Double {
        let goals = getMonthData(for: date).monthlyGoals
        guard !goals.isEmpty else { return 0.0 }
        return Double(goals.filter { $0.isCompleted }.count) / Double(goals.count)
    }

    private func persistData() {
        if let encoded = try? JSONEncoder().encode(reflections) { UserDefaults.standard.set(encoded, forKey: reflectionsKey) }
        if let encoded = try? JSONEncoder().encode(weekConfigs) { UserDefaults.standard.set(encoded, forKey: weekConfigsKey) }
        if let encoded = try? JSONEncoder().encode(monthConfigs) { UserDefaults.standard.set(encoded, forKey: monthConfigsKey) }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(appSettings) { UserDefaults.standard.set(encoded, forKey: settingsKey) }
        updateNotifications()
    }
    
    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: reflectionsKey), let decoded = try? JSONDecoder().decode([String: DailyNote].self, from: data) { self.reflections = decoded }
        if let data = UserDefaults.standard.data(forKey: weekConfigsKey), let decoded = try? JSONDecoder().decode([String: WeekData].self, from: data) { self.weekConfigs = decoded }
        if let data = UserDefaults.standard.data(forKey: monthConfigsKey), let decoded = try? JSONDecoder().decode([String: MonthData].self, from: data) { self.monthConfigs = decoded }
        if let data = UserDefaults.standard.data(forKey: settingsKey), let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) { self.appSettings = decoded }
    }

    func updateNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    center.removeAllPendingNotificationRequests()
                    if self.appSettings.goalNotificationEnabled {
                        let content = UNMutableNotificationContent(); content.title = "🎯 今日の目標"; content.body = "今日のタスクを確認しましょう！"; content.sound = .default
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: self.appSettings.goalNotificationTime)
                        center.add(UNNotificationRequest(identifier: "GoalNotification", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
                    }
                    if self.appSettings.reflectionNotificationEnabled {
                        let content = UNMutableNotificationContent(); content.title = "📝 振り返りの時間"; content.body = "今日のKPTを振り返りましょう！"; content.sound = .default
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: self.appSettings.reflectionNotificationTime)
                        center.add(UNNotificationRequest(identifier: "ReflectionNotification", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
                    }
                }
            }
        }
    }

    func syncAll(for date: Date) {
        syncGoalsToTasks(for: date)
        syncWeeklyGoals(for: date)
    }

    func syncGoalsToTasks(for date: Date) {
        var note = getNote(for: date); let monthData = getMonthData(for: date); var addedAny = false
        for goal in monthData.dailyGoals {
            let title = "日次: " + goal.title
            if !note.tasks.contains(where: { $0.title == title }) { note.tasks.append(Task(title: title)); addedAny = true }
        }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        for tryItem in getNote(for: yesterday).tryList {
            if !tryItem.isEmpty {
                let title = "昨日のTry: " + tryItem
                if !note.tasks.contains(where: { $0.title == title }) { note.tasks.append(Task(title: title)); addedAny = true }
            }
        }
        if addedAny { saveNote(note, for: date) }
    }
    
    func syncWeeklyGoals(for date: Date) {
        var weekData = getWeekData(for: date)
        let monthData = getMonthData(for: date)
        var addedAny = false
        for goal in monthData.weeklyGoals {
            if !weekData.goals.contains(where: { $0.title == goal.title }) {
                weekData.goals.append(Goal(title: goal.title))
                addedAny = true
            }
        }
        if addedAny { saveWeekData(weekData, for: date) }
    }

    func getDailyTitle(for date: Date) -> String { return Self.titleDailyFormatter.string(from: date) }
    func getWeeklyTitle(for date: Date) -> String {
        let dates = getCustomWeekInfo(for: date).dates
        guard let first = dates.first, let last = dates.last else { return "" }
        return "\(Self.titleWeeklyFormatter.string(from: first)) 〜 \(Self.titleWeeklyFormatter.string(from: last))"
    }
    func getMonthlyTitle(for date: Date) -> String { return Self.titleMonthlyFormatter.string(from: date) }

    func dateKey(_ date: Date) -> String { return Self.ymdFormatter.string(from: date) }
    func weekKey(_ date: Date) -> String { return getCustomWeekInfo(for: date).key }
    func monthKey(_ date: Date) -> String { return Self.ymFormatter.string(from: date) }
}

// MARK: - 3. メイン画面
struct ContentView: View {
    @StateObject private var dataManager = AppDataManager()
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(dataManager: dataManager).tabItem { Image(systemName: "house"); Text("ホーム") }.tag(0)
            ReflectionView(dataManager: dataManager).tabItem { Image(systemName: "square.and.pencil"); Text("振り返り") }.tag(1)
            CalendarView(dataManager: dataManager, selectedTab: $selectedTab).tabItem { Image(systemName: "calendar"); Text("カレンダー") }.tag(2)
            SettingsView(dataManager: dataManager).tabItem { Image(systemName: "gearshape"); Text("設定") }.tag(3)
        }.onTapGesture { hideKeyboard() }
    }
}

// MARK: - 4. ホーム画面
struct HomeView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var newTaskTitle = ""; @State private var showResetAlert = false
    var body: some View {
        NavigationView {
            VStack {
                Text(dataManager.dateKey(dataManager.selectedDate)).font(.caption).foregroundColor(.gray)
                HStack {
                    TextField("新しいタスク...", text: $newTaskTitle).textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: {
                        if !newTaskTitle.isEmpty {
                            var note = dataManager.getNote(for: dataManager.selectedDate)
                            note.tasks.append(Task(title: newTaskTitle))
                            dataManager.saveNote(note, for: dataManager.selectedDate)
                            newTaskTitle = ""
                        }
                    }) { Image(systemName: "plus.circle.fill").font(.title) }
                }.padding()
                List {
                    Section {
                        let currentTasks = dataManager.getNote(for: dataManager.selectedDate).tasks
                        ForEach(currentTasks) { task in
                            HStack {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(task.isCompleted ? .green : .gray)
                                
                                // 🌟 プレフィックスに応じてアイコンを表示
                                if task.title.hasPrefix("日次: ") {
                                    Image(systemName: "circle.fill").foregroundColor(.green).font(.system(size: 10))
                                    Text(task.title.replacingOccurrences(of: "日次: ", with: "")).strikethrough(task.isCompleted)
                                } else if task.title.hasPrefix("昨日のTry: ") {
                                    Image(systemName: "flame.fill").foregroundColor(.red).font(.system(size: 12))
                                    Text(task.title.replacingOccurrences(of: "昨日のTry: ", with: "")).strikethrough(task.isCompleted)
                                } else {
                                    Text(task.title).strikethrough(task.isCompleted)
                                }
                            }.onTapGesture {
                                var note = dataManager.getNote(for: dataManager.selectedDate)
                                if let i = note.tasks.firstIndex(where: { $0.id == task.id }) {
                                    note.tasks[i].isCompleted.toggle()
                                    dataManager.saveNote(note, for: dataManager.selectedDate)
                                }
                            }
                        }.onDelete { offsets in
                            var note = dataManager.getNote(for: dataManager.selectedDate)
                            note.tasks.remove(atOffsets: offsets)
                            dataManager.saveNote(note, for: dataManager.selectedDate)
                        }
                    }
                }
            }.navigationTitle("今日のタスク").id(dataManager.selectedDate)
            .onAppear { dataManager.syncAll(for: dataManager.selectedDate) }
            .onChange(of: dataManager.selectedDate) { _, newDate in dataManager.syncAll(for: newDate) }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button(action: { showResetAlert = true }) { Image(systemName: "trash").foregroundColor(.red) } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { hideKeyboard() } }
            }
            .alert("全データをリセット", isPresented: $showResetAlert) {
                Button("キャンセル", role: .cancel) { }; Button("削除する", role: .destructive) { dataManager.resetAllData() }
            } message: { Text("保存されているすべてのデータが消去されます。") }
        }
    }
}

// MARK: - 5. 振り返り画面
struct ReflectionView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var reflectionType = 0
    
    private var isSunday: Bool { Calendar.current.component(.weekday, from: dataManager.selectedDate) == 1 }
    private var isLastDayOfMonth: Bool {
        let cal = Calendar.current; let date = dataManager.selectedDate
        let nextDay = cal.date(byAdding: .day, value: 1, to: date)!
        return cal.component(.month, from: date) != cal.component(.month, from: nextDay)
    }
    
    var body: some View {
        let note = dataManager.getNote(for: dataManager.selectedDate)
        let weekData = dataManager.getWeekData(for: dataManager.selectedDate)
        let monthData = dataManager.getMonthData(for: dataManager.selectedDate)
        
        NavigationView {
            VStack {
                Picker("振り返り", selection: $reflectionType) {
                    Text("日次").tag(0)
                    if isSunday { Text("週次").tag(1) }
                    if isLastDayOfMonth { Text("月次").tag(2) }
                }
                .pickerStyle(SegmentedPickerStyle()).padding()
                .onChange(of: dataManager.selectedDate) { _, _ in
                    if reflectionType == 1 && !isSunday { reflectionType = 0 }
                    if reflectionType == 2 && !isLastDayOfMonth { reflectionType = 0 }
                }
                
                if reflectionType == 0 {
                    ReflectionAchievementCard(title: "\(dataManager.getDailyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getDailyCompletionRate(for: dataManager.selectedDate), rate2: nil, rate3: nil, color2: .clear, color3: .clear)
                } else if reflectionType == 1 {
                    ReflectionAchievementCard(title: "\(dataManager.getWeeklyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getWeeklyDailyAvgRate(for: dataManager.selectedDate), rate2: dataManager.getWeeklyGoalRate(for: dataManager.selectedDate), rate3: nil, color2: .orange, color3: .clear)
                } else {
                    ReflectionAchievementCard(title: "\(dataManager.getMonthlyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getMonthlyDailyAvgRate(for: dataManager.selectedDate), rate2: dataManager.getMonthlyWeeklyGoalAvgRate(for: dataManager.selectedDate), rate3: dataManager.getMonthlyGoalRate(for: dataManager.selectedDate), color2: .orange, color3: .blue)
                }

                ScrollView {
                    VStack(spacing: 15) {
                        if reflectionType == 0 {
                            VStack(alignment: .leading, spacing: 10) {
                                TextEditorView(title: "Keep", text: Binding(get: { note.keep }, set: { updateNote($0, f: .keep) }))
                                TextEditorView(title: "Problem", text: Binding(get: { note.problem }, set: { updateNote($0, f: .problem) }))
                                BulletInputSection(title: "Try", items: note.tryList) { newList in var n = dataManager.getNote(for: dataManager.selectedDate); n.tryList = newList; dataManager.saveNote(n, for: dataManager.selectedDate) }
                            }.padding(.horizontal)
                        } else if reflectionType == 1 {
                            VStack(alignment: .leading, spacing: 10) {
                                GoalListSection(title: "今週の目標チェック", iconColor: .orange, goals: weekData.goals, showCheckboxes: true, onUpdate: { var d = dataManager.getWeekData(for: dataManager.selectedDate); d.goals = $0; dataManager.saveWeekData(d, for: dataManager.selectedDate) })
                                if isSunday {
                                    TextEditorView(title: "今週の振り返り", text: Binding(get: { weekData.reflection }, set: { var d = dataManager.getWeekData(for: dataManager.selectedDate); d.reflection = $0; dataManager.saveWeekData(d, for: dataManager.selectedDate) }), minHeight: 120)
                                } else {
                                    VStack(alignment: .leading) {
                                        Text("今週の振り返り (※編集は週の最終日のみ)").font(.caption).foregroundColor(.gray)
                                        Text(weekData.reflection.isEmpty ? "未記入" : weekData.reflection).padding(8).frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading).background(Color(.systemGray6)).cornerRadius(8)
                                    }.padding(.vertical, 4)
                                }
                            }.padding(.horizontal)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                GoalListSection(title: "今月の目標チェック", iconColor: .blue, goals: monthData.monthlyGoals, showCheckboxes: true, onUpdate: { var d = dataManager.getMonthData(for: dataManager.selectedDate); d.monthlyGoals = $0; dataManager.saveMonthData(d, for: dataManager.selectedDate) })
                                if isLastDayOfMonth {
                                    TextEditorView(title: "今月の振り返り", text: Binding(get: { monthData.reflection }, set: { var d = dataManager.getMonthData(for: dataManager.selectedDate); d.reflection = $0; dataManager.saveMonthData(d, for: dataManager.selectedDate) }), minHeight: 120)
                                } else {
                                    VStack(alignment: .leading) {
                                        Text("今月の振り返り (※編集は月末のみ)").font(.caption).foregroundColor(.gray)
                                        Text(monthData.reflection.isEmpty ? "未記入" : monthData.reflection).padding(8).frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading).background(Color(.systemGray6)).cornerRadius(8)
                                    }.padding(.vertical, 4)
                                }
                            }.padding(.horizontal)
                        }
                    }.padding(.vertical)
                }
            }
            .navigationTitle("振り返り")
            .onAppear { dataManager.syncAll(for: dataManager.selectedDate) }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { hideKeyboard() } }
            }
        }
    }
    enum F { case keep, problem }
    func updateNote(_ t: String, f: F) { var n = dataManager.getNote(for: dataManager.selectedDate); if f == .keep { n.keep = t } else { n.problem = t }; dataManager.saveNote(n, for: dataManager.selectedDate) }
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
                    HStack(spacing: 10) {
                        CompositeSummaryCard(title: "\(dataManager.getWeeklyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getWeeklyDailyAvgRate(for: dataManager.selectedDate), rate2: dataManager.getWeeklyGoalRate(for: dataManager.selectedDate), rate3: nil, color2: .orange, color3: .clear)
                        CompositeSummaryCard(title: "\(monthString(calendarDisplayDate))の達成度", rate1: dataManager.getMonthlyDailyAvgRate(for: calendarDisplayDate), rate2: dataManager.getMonthlyWeeklyGoalAvgRate(for: calendarDisplayDate), rate3: dataManager.getMonthlyGoalRate(for: calendarDisplayDate), color2: .orange, color3: .blue)
                    }.padding(.horizontal)

                    VStack(spacing: 10) {
                        GoalListSection(title: "\(monthString(calendarDisplayDate))の月次目標", iconColor: .blue, goals: monthData.monthlyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: calendarDisplayDate); d.monthlyGoals = $0; dataManager.saveMonthData(d, for: calendarDisplayDate); dataManager.syncAll(for: dataManager.selectedDate) }) {
                            copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate)!).monthlyGoals, field: .monthly)
                        }
                        GoalListSection(title: "\(monthString(calendarDisplayDate))の週次目標", iconColor: .orange, goals: monthData.weeklyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: calendarDisplayDate); d.weeklyGoals = $0; dataManager.saveMonthData(d, for: calendarDisplayDate); dataManager.syncAll(for: dataManager.selectedDate) }) {
                            copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate)!).weeklyGoals, field: .weekly)
                        }
                        GoalListSection(title: "\(monthString(calendarDisplayDate))の日次目標", iconColor: .green, goals: monthData.dailyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: calendarDisplayDate); d.dailyGoals = $0; dataManager.saveMonthData(d, for: calendarDisplayDate); dataManager.syncAll(for: dataManager.selectedDate) }) {
                            copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate)!).dailyGoals, field: .daily)
                        }
                    }.padding(.horizontal)

                    HStack {
                        Button(action: { calendarDisplayDate = Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate)! }) { Image(systemName: "chevron.left") }
                        Spacer(); Text(monthString(calendarDisplayDate)).font(.headline); Spacer()
                        Button(action: { calendarDisplayDate = Calendar.current.date(byAdding: .month, value: 1, to: calendarDisplayDate)! }) { Image(systemName: "chevron.right") }
                    }.padding(.horizontal)
                    
                    CalendarGridView(dataManager: dataManager, displayDate: calendarDisplayDate, selectedDate: $dataManager.selectedDate, selectedTab: $selectedTab)
                }
            }
            .navigationTitle("カレンダー")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { hideKeyboard() } }
            }
        }
    }
    func monthString(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy年 M月"; return f.string(from: d) }
    enum F { case monthly, weekly, daily }
    
    func copyPrev(prev: [Goal], field: F) {
        var curr: [Goal]
        switch field {
        case .monthly: curr = dataManager.getMonthData(for: calendarDisplayDate).monthlyGoals
        case .weekly: curr = dataManager.getMonthData(for: calendarDisplayDate).weeklyGoals
        case .daily: curr = dataManager.getMonthData(for: calendarDisplayDate).dailyGoals
        }
        let titles = curr.map { $0.title }
        var new = curr; for g in prev { if !titles.contains(g.title) { new.append(Goal(title: g.title)) } }
        var d = dataManager.getMonthData(for: calendarDisplayDate)
        if field == .monthly { d.monthlyGoals = new }
        else if field == .weekly { d.weeklyGoals = new }
        else { d.dailyGoals = new }
        dataManager.saveMonthData(d, for: calendarDisplayDate)
        dataManager.syncAll(for: dataManager.selectedDate)
    }
}

// 🌟 設定画面
struct SettingsView: View {
    @ObservedObject var dataManager: AppDataManager
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("目標の通知")) {
                    Toggle("オン", isOn: Binding(get: { dataManager.appSettings.goalNotificationEnabled }, set: { dataManager.appSettings.goalNotificationEnabled = $0; dataManager.saveSettings() }))
                    if dataManager.appSettings.goalNotificationEnabled { DatePicker("時間", selection: Binding(get: { dataManager.appSettings.goalNotificationTime }, set: { dataManager.appSettings.goalNotificationTime = $0; dataManager.saveSettings() }), displayedComponents: .hourAndMinute) }
                }
                Section(header: Text("振り返りの通知")) {
                    Toggle("オン", isOn: Binding(get: { dataManager.appSettings.reflectionNotificationEnabled }, set: { dataManager.appSettings.reflectionNotificationEnabled = $0; dataManager.saveSettings() }))
                    if dataManager.appSettings.reflectionNotificationEnabled { DatePicker("時間", selection: Binding(get: { dataManager.appSettings.reflectionNotificationTime }, set: { dataManager.appSettings.reflectionNotificationTime = $0; dataManager.saveSettings() }), displayedComponents: .hourAndMinute) }
                }
            }.navigationTitle("設定")
        }
    }
}

// MARK: - 補助コンポーネント (3色円グラフ対応)

struct ReflectionAchievementCard: View {
    let title: String; let rate1: Double; let rate2: Double?; let rate3: Double?; let color2: Color; let color3: Color
    var body: some View {
        let count = (rate3 != nil ? 3.0 : (rate2 != nil ? 2.0 : 1.0))
        let total = (rate1 + (rate2 ?? 0) + (rate3 ?? 0)) / count
        VStack(spacing: 12) {
            Text(title).font(.subheadline).foregroundColor(.secondary).bold()
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Int(total * 100))%").font(.system(size: 40, weight: .bold, design: .rounded))
                    HStack(spacing: 6) { Circle().fill(Color.green).frame(width: 10, height: 10); Text("日次タスク: \(Int(rate1 * 100))%").font(.caption).foregroundColor(.gray) }
                    if let r2 = rate2 { HStack(spacing: 6) { Circle().fill(color2).frame(width: 10, height: 10); Text("週の目標: \(Int(r2 * 100))%").font(.caption).foregroundColor(.gray) } }
                    if let r3 = rate3 { HStack(spacing: 6) { Circle().fill(color3).frame(width: 10, height: 10); Text("月の目標: \(Int(r3 * 100))%").font(.caption).foregroundColor(.gray) } }
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.15), lineWidth: 10)
                    Circle().trim(from: 0, to: rate1 / count).stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                    if let r2 = rate2 { Circle().trim(from: rate1 / count, to: (rate1 + r2) / count).stroke(color2, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90)) }
                    if let r2 = rate2, let r3 = rate3 { Circle().trim(from: (rate1 + r2) / count, to: (rate1 + r2 + r3) / count).stroke(color3, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90)) }
                }.frame(width: 80, height: 80)
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(15).shadow(radius: 2).padding(.horizontal)
    }
}

struct CompositeSummaryCard: View {
    let title: String; let rate1: Double; let rate2: Double?; let rate3: Double?; let color2: Color; let color3: Color
    var body: some View {
        let count = (rate3 != nil ? 3.0 : (rate2 != nil ? 2.0 : 1.0))
        let total = (rate1 + (rate2 ?? 0) + (rate3 ?? 0)) / count
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(total * 100))%").font(.headline).bold()
                    HStack(spacing: 4) { Circle().fill(Color.green).frame(width: 6, height: 6); Text("日次: \(Int(rate1 * 100))%").font(.system(size: 9)).foregroundColor(.gray) }
                    if let r2 = rate2 { HStack(spacing: 4) { Circle().fill(color2).frame(width: 6, height: 6); Text("週次: \(Int(r2 * 100))%").font(.system(size: 9)).foregroundColor(.gray) } }
                    if let r3 = rate3 {
                        HStack(spacing: 4) { Circle().fill(color3).frame(width: 6, height: 6); Text("月次: \(Int(r3 * 100))%").font(.system(size: 9)).foregroundColor(.gray) }
                    } else {
                        HStack(spacing: 4) { Circle().fill(Color.clear).frame(width: 6, height: 6); Text(" ").font(.system(size: 9)) }
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.15), lineWidth: 5)
                    Circle().trim(from: 0, to: rate1 / count).stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                    if let r2 = rate2 { Circle().trim(from: rate1 / count, to: (rate1 + r2) / count).stroke(color2, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)) }
                    if let r2 = rate2, let r3 = rate3 { Circle().trim(from: (rate1 + r2) / count, to: (rate1 + r2 + r3) / count).stroke(color3, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)) }
                }.frame(width: 35, height: 35)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

// 🌟 改善点: アイコンの色を引数で受け取るようにし、シンプルな丸いアイコンを表示
struct GoalListSection: View {
    let title: String; let iconColor: Color; var goals: [Goal]; var showCheckboxes: Bool; var onUpdate: ([Goal]) -> Void; var onCopy: (() -> Void)? = nil
    @State private var temp = ""; @State private var show = false
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                // 🌟 タイトルの前に色付きの丸を表示
                Image(systemName: "circle.fill").foregroundColor(iconColor).font(.system(size: 10))
                Text(title).font(.caption).bold().foregroundColor(.primary)
                Spacer()
                if let onCopy = onCopy { Button(action: onCopy) { Image(systemName: "doc.on.clipboard").font(.system(size: 12)) }.padding(.trailing, 5) }
                Button(action: { show = true }) { Image(systemName: "plus").font(.system(size: 12, weight: .bold)) }
            }
            ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                HStack {
                    if showCheckboxes {
                        Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(goal.isCompleted ? .green : .gray)
                            .onTapGesture {
                                var newGoals = goals
                                newGoals[index].isCompleted.toggle()
                                onUpdate(newGoals)
                            }
                    }
                    else { Text("・").foregroundColor(iconColor) }
                    Text(goal.title).font(.subheadline).strikethrough(showCheckboxes && goal.isCompleted); Spacer()
                    Button(action: {
                        var newGoals = goals
                        newGoals.remove(at: index)
                        onUpdate(newGoals)
                    }) { Image(systemName: "xmark.circle").foregroundColor(.gray) }
                }.padding(.vertical, 1)
            }
        }.padding(10).background(Color(.systemBackground)).cornerRadius(8).shadow(radius: 1)
        .alert("追加", isPresented: $show) {
            TextField("...", text: $temp); Button("キャンセル", role: .cancel) { temp = "" }; Button("追加") { if !temp.isEmpty { var n = goals; n.append(Goal(title: temp)); onUpdate(n); temp = "" } }
        }
    }
}

struct CalendarGridView: View {
    @ObservedObject var dataManager: AppDataManager; let displayDate: Date; @Binding var selectedDate: Date; @Binding var selectedTab: Int
    let cols = Array(repeating: GridItem(.flexible()), count: 7)
    var body: some View {
        let days = generateDays(); let today = Calendar.current.startOfDay(for: Date())
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(0..<days.count, id: \.self) { i in
                if let d = days[i] {
                    let isSel = Calendar.current.isDate(d, inSameDayAs: selectedDate); let isFut = d > today
                    RoundedRectangle(cornerRadius: 6).fill(isFut ? Color(.systemGray6) : getCol(d))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSel ? Color.blue : Color.clear, lineWidth: isSel ? 3 : 0))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Text("\(Calendar.current.component(.day, from: d))").font(.caption).foregroundColor(isFut ? .gray : (rate(d) >= 0.75 ? .white : .primary)))
                        .simultaneousGesture(TapGesture(count: 2).onEnded {
                            if !isFut { selectedDate = d; selectedTab = 1 }
                        })
                        .simultaneousGesture(TapGesture(count: 1).onEnded {
                            if !isFut { selectedDate = d }
                        })
                } else { Color.clear }
            }
        }.padding()
    }
    func rate(_ d: Date) -> Double { dataManager.getDailyCompletionRate(for: d) }
    
    func getCol(_ d: Date) -> Color {
        let r = rate(d)
        let note = dataManager.getNote(for: d)
        let hasReflection = !note.keep.isEmpty || !note.problem.isEmpty || !note.tryList.isEmpty
        if r == 0 && !hasReflection { return Color(.systemGray6) }
        if r == 0 { return Color.green.opacity(0.1) }
        switch r {
        case ..<0.25: return Color.green.opacity(0.25)
        case 0.25..<0.5: return Color.green.opacity(0.5)
        case 0.5..<0.75: return Color.green.opacity(0.7)
        case 0.75..<1.0: return Color.green.opacity(0.85)
        default: return Color.green
        }
    }
    
    func generateDays() -> [Date?] {
        let cal = Calendar.current; let start = cal.date(from: cal.dateComponents([.year, .month], from: displayDate))!; let range = cal.range(of: .day, in: .month, for: start)!; let firstDay = cal.component(.weekday, from: start)
        var days: [Date?] = Array(repeating: nil, count: firstDay - 1); for i in 0..<range.count { days.append(cal.date(byAdding: .day, value: i, to: start)!) }; return days
    }
}

struct BulletInputSection: View {
    let title: String; var items: [String]; var onUpdate: ([String]) -> Void
    @State private var t = ""; @State private var s = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.caption).foregroundColor(.gray); Spacer(); Button(action: { s = true }) { Image(systemName: "plus.circle.fill") } }
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack { Text("・").foregroundColor(.blue); Text(item).font(.body); Spacer(); Button(action: { var n = items; n.remove(at: index); onUpdate(n) }) { Image(systemName: "xmark.circle").foregroundColor(.gray) } }
            }
        }.alert("Try追加", isPresented: $s) {
            TextField("...", text: $t); Button("追加") { if !t.isEmpty { var n = items; n.append(t); onUpdate(n); t = "" } }; Button("キャンセル", role: .cancel) { t = "" }
        }
    }
}

struct TextEditorView: View {
    let title: String; @Binding var text: String; var minHeight: CGFloat = 60
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.gray)
            TextField("入力...", text: $text, axis: .vertical).lineLimit(4...15).padding(8).background(Color(.systemGray6)).cornerRadius(8).frame(minHeight: minHeight, alignment: .top)
        }.padding(.vertical, 4)
    }
}

#Preview { ContentView() }
