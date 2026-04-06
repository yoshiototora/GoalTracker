
//
//  AppDataManager.swift
//  GoalTracker
//

import SwiftUI
import Combine
import UserNotifications

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
    
    // 保存処理のデバウンス用
    private var saveWorkItem: DispatchWorkItem?
    
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
            // クラッシュ対策: ! を削除し、失敗時はstartOfMonthを返す
            let currentDate = cal.date(byAdding: .day, value: dayOffset, to: startOfMonth) ?? startOfMonth
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

    func getMonthDates(for date: Date) -> [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: date),
              let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: date)) else { return [] }
        return (0..<range.count).compactMap { cal.date(byAdding: .day, value: $0, to: startOfMonth) }
    }

    func getMonthlyDailyAvgRate(for date: Date) -> Double {
        let dates = getMonthDates(for: date)
        guard !dates.isEmpty else { return 0 }
        let sum = dates.map { getDailyCompletionRate(for: $0) }.reduce(0, +)
        return sum / Double(dates.count)
    }

    func getMonthlyWeeklyGoalAvgRate(for date: Date) -> Double {
        let dates = getMonthDates(for: date)
        var weekKeysInMonth = Set<String>()
        for d in dates { weekKeysInMonth.insert(weekKey(d)) }
        
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

    func getCompletedTasksCount(for date: Date, isWeekly: Bool) -> Int {
        let dates = isWeekly ? getCustomWeekInfo(for: date).dates : getMonthDates(for: date)
        return dates.reduce(0) { sum, d in sum + getNote(for: d).tasks.filter { $0.isCompleted }.count }
    }

    func getTryExecutionCount(for date: Date, isWeekly: Bool) -> Int {
        let dates = isWeekly ? getCustomWeekInfo(for: date).dates : getMonthDates(for: date)
        return dates.reduce(0) { sum, d in
            sum + getNote(for: d).tasks.filter { $0.isCompleted && ($0.title.hasPrefix("昨日のTry: ") || $0.title.hasPrefix("🔥 【昨日のTry】")) }.count
        }
    }

    func getComparisonText(for date: Date, isWeekly: Bool) -> String {
        let currentRate = isWeekly ? getWeeklyDailyAvgRate(for: date) : getMonthlyDailyAvgRate(for: date)
        // クラッシュ対策
        let prevDate = Calendar.current.date(byAdding: isWeekly ? .day : .month, value: isWeekly ? -7 : -1, to: date) ?? date
        let prevRate = isWeekly ? getWeeklyDailyAvgRate(for: prevDate) : getMonthlyDailyAvgRate(for: prevDate)
        
        let diff = Int((currentRate - prevRate) * 100)
        if diff > 0 { return "先\(isWeekly ? "週" : "月")より ＋\(diff)% アップ！🔥" }
        else if diff < 0 { return "先\(isWeekly ? "週" : "月")より \(diff)% 📉" }
        else { return "先\(isWeekly ? "週" : "月")と同じペースです！✨" }
    }

    // パフォーマンス改善：バックグラウンドでの遅延保存処理
    private func persistData() {
        saveWorkItem?.cancel()
        
        let currentReflections = self.reflections
        let currentWeekConfigs = self.weekConfigs
        let currentMonthConfigs = self.monthConfigs
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if let encoded = try? JSONEncoder().encode(currentReflections) { UserDefaults.standard.set(encoded, forKey: self.reflectionsKey) }
            if let encoded = try? JSONEncoder().encode(currentWeekConfigs) { UserDefaults.standard.set(encoded, forKey: self.weekConfigsKey) }
            if let encoded = try? JSONEncoder().encode(currentMonthConfigs) { UserDefaults.standard.set(encoded, forKey: self.monthConfigsKey) }
        }
        self.saveWorkItem = workItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5, execute: workItem)
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
            DispatchQueue.main.async {
                if granted {
                    center.removePendingNotificationRequests(withIdentifiers: ["GoalNotification", "ReflectionNotification"])
                    if self.appSettings.goalNotificationEnabled {
                        let content = UNMutableNotificationContent(); content.title = "🟢 今日の目標"; content.body = "今日のタスクを確認しましょう！"; content.sound = .default
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: self.appSettings.goalNotificationTime)
                        center.add(UNNotificationRequest(identifier: "GoalNotification", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
                    }
                    if self.appSettings.reflectionNotificationEnabled {
                        let content = UNMutableNotificationContent(); content.title = "📝 振り返りの時間"; content.body = "今日のKPTを振り返りましょう！"; content.sound = .default
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: self.appSettings.reflectionNotificationTime)
                        center.add(UNNotificationRequest(identifier: "ReflectionNotification", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
                    }
                } else {
                    // バグ修正：許可されなかった場合、トグルをオフに戻す
                    self.appSettings.goalNotificationEnabled = false
                    self.appSettings.reflectionNotificationEnabled = false
                }
            }
        }
    }

    func syncAll(for date: Date) {
        syncGoalsToTasks(for: date)
        syncWeeklyGoals(for: date)
    }

    func syncGoalsToTasks(for date: Date) {
        var note = getNote(for: date)
        let monthData = getMonthData(for: date)
        
        // 1. 現在有効な目標・Tryのリストを作成
        let currentDailyGoalTitles = monthData.dailyGoals.map { "日次: " + $0.title }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let yesterdayTryTitles = getNote(for: yesterday).tryList.filter { !$0.isEmpty }.map { "昨日のTry: " + $0 }
        
        // 2. 古くなった未完了タスク（ゴーストタスク）を削除
        note.tasks.removeAll { task in
            if task.title.hasPrefix("日次: ") && !task.isCompleted {
                return !currentDailyGoalTitles.contains(task.title)
            }
            if task.title.hasPrefix("昨日のTry: ") && !task.isCompleted {
                return !yesterdayTryTitles.contains(task.title)
            }
            return false
        }
        
        // 3. 新しい目標・Tryを追加
        for title in currentDailyGoalTitles {
            if !note.tasks.contains(where: { $0.title == title }) { note.tasks.append(Task(title: title)) }
        }
        for title in yesterdayTryTitles {
            if !note.tasks.contains(where: { $0.title == title }) { note.tasks.append(Task(title: title)) }
        }
        
        saveNote(note, for: date)
    }
    
    func syncWeeklyGoals(for date: Date) {
        var weekData = getWeekData(for: date)
        let monthData = getMonthData(for: date)
        
        let currentWeeklyGoalTitles = monthData.weeklyGoals.map { $0.title }
        
        // ゴーストタスク削除
        weekData.goals.removeAll { goal in
            if !goal.isCompleted {
                return !currentWeeklyGoalTitles.contains(goal.title)
            }
            return false
        }
        
        for goal in monthData.weeklyGoals {
            if !weekData.goals.contains(where: { $0.title == goal.title }) {
                weekData.goals.append(Goal(title: goal.title))
            }
        }
        
        saveWeekData(weekData, for: date)
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
