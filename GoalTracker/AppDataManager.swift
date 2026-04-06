//
//  AppDataManager.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/06.
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
