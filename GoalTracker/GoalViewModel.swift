//
//  GoalViewModel.swift
//  GoalTracker
//

import SwiftUI
import Combine

class GoalViewModel: ObservableObject {
    @Published var selectedDate: Date = Date() {
        didSet { loadCachedData() }
    }
    @Published var appSettings: AppSettings = AppSettings()
    @Published var futureVisions: [FutureVision] = []
    
    @Published var currentDailyNote: DailyNote = DailyNote()
    @Published var currentWeekData: WeekData = WeekData()
    @Published var currentMonthData: MonthData = MonthData()
    @Published var nextMonthData: MonthData = MonthData()
    @Published var currentDailyStreak: Int = 0
    
    private let coreData = CoreDataService.shared
    private let ymdFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }()
    private let ymFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f }()
    private let settingsKey = "app_settings_storage"
    
    init() {
        loadSettings()
        loadFutureVisions()
        loadCachedData()
    }
    
    // MARK: - Keys & Titles
    func dateKey(_ date: Date) -> String { return ymdFormatter.string(from: date) }
    func monthKey(_ date: Date) -> String { return ymFormatter.string(from: date) }
    func getCustomWeekInfo(for date: Date) -> (key: String, dates: [Date]) {
        let cal = Calendar.current; let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
        let daysInMonth = cal.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
        var currentWeekDates: [Date] = []; var currentWeekNumber = 1; var targetWeekNumber = 1; var targetWeekDates: [Date] = []
        for dayOffset in 0..<daysInMonth {
            let currentDate = cal.date(byAdding: .day, value: dayOffset, to: startOfMonth) ?? startOfMonth
            currentWeekDates.append(currentDate)
            if cal.isDate(currentDate, inSameDayAs: date) { targetWeekNumber = currentWeekNumber }
            if cal.component(.weekday, from: currentDate) == 1 || dayOffset == daysInMonth - 1 {
                if targetWeekNumber == currentWeekNumber { targetWeekDates = currentWeekDates }
                currentWeekNumber += 1; currentWeekDates = []
            }
        }
        return (String(format: "%04d-%02d-W%d", cal.component(.year, from: date), cal.component(.month, from: date), targetWeekNumber), targetWeekDates)
    }
    
    func getDailyTitle(for date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy年M月d日"; return f.string(from: date) }
    func getWeeklyTitle(for date: Date) -> String {
        let dates = getCustomWeekInfo(for: date).dates; guard let first = dates.first, let last = dates.last else { return "" }
        let f = DateFormatter(); f.dateFormat = "M/d"; return "\(f.string(from: first)) 〜 \(f.string(from: last))"
    }
    func getMonthlyTitle(for date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy年M月"; return f.string(from: date) }
    
    // MARK: - Data Fetching
    func getNote(for date: Date) -> DailyNote { return coreData.fetchDailyNote(for: dateKey(date)) }
    func getWeekData(for date: Date) -> WeekData { return coreData.fetchWeekData(for: getCustomWeekInfo(for: date).key) }
    func getMonthData(for date: Date) -> MonthData { return coreData.fetchMonthData(for: monthKey(date)) }
    
    func loadCachedData() {
        currentDailyNote = getNote(for: selectedDate)
        currentWeekData = getWeekData(for: selectedDate)
        currentMonthData = getMonthData(for: selectedDate)
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        nextMonthData = getMonthData(for: nextMonth)
        currentDailyStreak = calculateDailyStreak()
    }
    
    // MARK: - Tasks Updates
    func addTask(title: String, for date: Date) {
        var note = getNote(for: date); note.tasks.append(Task(title: title, type: .normal))
        coreData.saveDailyNote(note, for: dateKey(date))
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
        currentDailyStreak = calculateDailyStreak()
    }
    func toggleTask(id: UUID, for date: Date) {
        var note = getNote(for: date)
        if let idx = note.tasks.firstIndex(where: { $0.id == id }) {
            note.tasks[idx].isCompleted.toggle()
            coreData.saveDailyNote(note, for: dateKey(date))
            if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
            currentDailyStreak = calculateDailyStreak()
        }
    }
    func removeTasks(at offsets: IndexSet, for date: Date) {
        var note = getNote(for: date); note.tasks.remove(atOffsets: offsets)
        coreData.saveDailyNote(note, for: dateKey(date))
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
        currentDailyStreak = calculateDailyStreak()
    }
    
    // 🟢 追加：タスクの編集機能
    func editTask(id: UUID, newTitle: String, newCategoryId: String, for date: Date) {
        var note = getNote(for: date)
        if let idx = note.tasks.firstIndex(where: { $0.id == id }) {
            note.tasks[idx].title = newTitle
            note.tasks[idx].categoryId = newCategoryId
            coreData.saveDailyNote(note, for: dateKey(date))
            if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
        }
    }
    
    // MARK: - KPT Updates
    enum ReflectionField { case keep, problem, reflection }
    func updateDailyNote(_ text: String, field: ReflectionField, date: Date) {
        var note = getNote(for: date); if field == .keep { note.keep = text } else { note.problem = text }
        coreData.saveDailyNote(note, for: dateKey(date))
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
    }
    func updateDailyTryList(_ list: [String], date: Date) {
        var note = getNote(for: date); note.tryList = list
        coreData.saveDailyNote(note, for: dateKey(date))
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
    }
    
    func updateWeeklyText(_ text: String, field: ReflectionField, date: Date) {
        var data = getWeekData(for: date)
        if field == .keep { data.keep = text } else if field == .problem { data.problem = text } else { data.reflection = text }
        coreData.saveWeekData(data, for: getCustomWeekInfo(for: date).key)
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentWeekData = data }
    }
    func updateWeeklyGoals(_ goals: [Goal], date: Date) {
        var data = getWeekData(for: date); data.goals = goals
        coreData.saveWeekData(data, for: getCustomWeekInfo(for: date).key)
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentWeekData = data }
    }
    func updateWeeklyTryList(_ list: [String], date: Date) {
        var data = getWeekData(for: date); data.tryList = list
        coreData.saveWeekData(data, for: getCustomWeekInfo(for: date).key)
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentWeekData = data }
    }
    
    enum GoalField { case monthly, weekly, daily }
    func updateMonthlyText(_ text: String, field: ReflectionField, date: Date) {
        var data = getMonthData(for: date)
        if field == .keep { data.keep = text } else if field == .problem { data.problem = text } else { data.reflection = text }
        coreData.saveMonthData(data, for: monthKey(date))
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentMonthData = data }
    }
    func updateMonthlyGoals(_ goals: [Goal], field: GoalField, date: Date) {
        var data = getMonthData(for: date)
        if field == .monthly { data.monthlyGoals = goals } else if field == .weekly { data.weeklyGoals = goals } else { data.dailyGoals = goals }
        coreData.saveMonthData(data, for: monthKey(date)); syncAll(for: date)
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentMonthData = data }
    }
    func updateMonthlyTryList(_ list: [String], date: Date) {
        var data = getMonthData(for: date); data.tryList = list
        coreData.saveMonthData(data, for: monthKey(date))
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentMonthData = data }
    }
    
    // MARK: - Calculations
    func calculateDailyStreak() -> Int {
        var streak = 0; var checkDate = selectedDate; let cal = Calendar.current
        while true {
            let tasks = getNote(for: checkDate).tasks
            if tasks.isEmpty || !tasks.allSatisfy({ $0.isCompleted }) { break }
            streak += 1; checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }
    func getDailyCompletionRate(for date: Date) -> Double {
        let tasks = getNote(for: date).tasks; guard !tasks.isEmpty else { return 0.0 }
        return Double(tasks.filter { $0.isCompleted }.count) / Double(tasks.count)
    }
    func getWeeklyDailyAvgRate(for date: Date) -> Double {
        let dates = getCustomWeekInfo(for: date).dates; guard !dates.isEmpty else { return 0 }
        return dates.map { getDailyCompletionRate(for: $0) }.reduce(0, +) / Double(dates.count)
    }
    func getWeeklyGoalRate(for date: Date) -> Double {
        let goals = getWeekData(for: date).goals; guard !goals.isEmpty else { return 0.0 }
        return Double(goals.filter { $0.isCompleted }.count) / Double(goals.count)
    }
    func getMonthDates(for date: Date) -> [Date] {
        let cal = Calendar.current; guard let range = cal.range(of: .day, in: .month, for: date), let start = cal.date(from: cal.dateComponents([.year, .month], from: date)) else { return [] }
        return (0..<range.count).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
    func getMonthlyDailyAvgRate(for date: Date) -> Double {
        let dates = getMonthDates(for: date); guard !dates.isEmpty else { return 0 }
        return dates.map { getDailyCompletionRate(for: $0) }.reduce(0, +) / Double(dates.count)
    }
    func getMonthlyWeeklyGoalAvgRate(for date: Date) -> Double {
        let dates = getMonthDates(for: date); var weekKeys = Set<String>()
        for d in dates { weekKeys.insert(getCustomWeekInfo(for: d).key) }
        let rates = weekKeys.map { key -> Double in let goals = coreData.fetchWeekData(for: key).goals; return goals.isEmpty ? 0.0 : Double(goals.filter { $0.isCompleted }.count) / Double(goals.count) }
        return rates.isEmpty ? 0 : rates.reduce(0, +) / Double(rates.count)
    }
    func getMonthlyGoalRate(for date: Date) -> Double {
        let goals = getMonthData(for: date).monthlyGoals; guard !goals.isEmpty else { return 0.0 }
        return Double(goals.filter { $0.isCompleted }.count) / Double(goals.count)
    }
    func getCompletedTasksCount(for date: Date, isWeekly: Bool) -> Int {
        let dates = isWeekly ? getCustomWeekInfo(for: date).dates : getMonthDates(for: date)
        return dates.reduce(0) { sum, d in sum + getNote(for: d).tasks.filter { $0.isCompleted }.count }
    }
    func getTryExecutionCount(for date: Date, isWeekly: Bool) -> Int {
        let dates = isWeekly ? getCustomWeekInfo(for: date).dates : getMonthDates(for: date)
        return dates.reduce(0) { sum, d in sum + getNote(for: d).tasks.filter { $0.isCompleted && $0.type == .tryCarryOver }.count }
    }
    func getComparisonText(for date: Date, isWeekly: Bool) -> String {
        let currentRate = isWeekly ? getWeeklyDailyAvgRate(for: date) : getMonthlyDailyAvgRate(for: date)
        let prevDate = Calendar.current.date(byAdding: isWeekly ? .day : .month, value: isWeekly ? -7 : -1, to: date) ?? date
        let prevRate = isWeekly ? getWeeklyDailyAvgRate(for: prevDate) : getMonthlyDailyAvgRate(for: prevDate)
        let diff = Int((currentRate - prevRate) * 100)
        if diff > 0 { return "先\(isWeekly ? "週" : "月")より ＋\(diff)% アップ！🔥" }
        else if diff < 0 { return "先\(isWeekly ? "週" : "月")より \(diff)% 📉" }
        else { return "先\(isWeekly ? "週" : "月")と同じペースです！✨" }
    }
    
    // MARK: - Category Helper
    func getCategory(id: String) -> CategoryItem {
        return appSettings.categories.first(where: { $0.id == id }) ?? CategoryItem(id: "none", name: "指定なし", colorName: "gray")
    }
    
    // MARK: - Baton & Sync
    func getYesterdayTryList(for date: Date) -> [String] { return getNote(for: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date).tryList.filter { !$0.isEmpty } }
    func getLastWeeklyTryList(for date: Date) -> [String] {
        var checkDate = date; let cal = Calendar.current
        while cal.component(.weekday, from: checkDate) != 1 { checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate }
        if cal.isDate(checkDate, inSameDayAs: date) { checkDate = cal.date(byAdding: .day, value: -7, to: checkDate) ?? checkDate }
        return getWeekData(for: checkDate).tryList
    }
    func getLastMonthlyTryList(for date: Date) -> [String] {
        let cal = Calendar.current; guard let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: date)), let prevLast = cal.date(byAdding: .day, value: -1, to: firstDay) else { return [] }
        return getMonthData(for: prevLast).tryList
    }
    
    func syncAll(for date: Date) {
        var note = getNote(for: date); let monthData = getMonthData(for: date)
        let dailyGoals = monthData.dailyGoals
        let dailyGoalTitles = dailyGoals.map { $0.title }
        let allTrys = (getYesterdayTryList(for: date).map{"昨日のTry: "+$0} + getLastWeeklyTryList(for: date).map{"先週のTry: "+$0} + getLastMonthlyTryList(for: date).map{"先月のTry: "+$0})
        
        note.tasks.removeAll { ($0.type == .dailyGoal && !dailyGoalTitles.contains($0.title)) || ($0.type == .tryCarryOver && !allTrys.contains($0.title)) }
        
        for g in dailyGoals {
            if !note.tasks.contains(where: { $0.title == g.title && $0.type == .dailyGoal }) {
                note.tasks.append(Task(title: g.title, type: .dailyGoal, categoryId: g.categoryId))
            }
        }
        for t in allTrys { if !note.tasks.contains(where: { $0.title == t && $0.type == .tryCarryOver }) { note.tasks.append(Task(title: t, type: .tryCarryOver)) } }
        coreData.saveDailyNote(note, for: dateKey(date))
        
        var weekData = getWeekData(for: date); let weeklyGoals = monthData.weeklyGoals.map { $0.title }
        weekData.goals.removeAll { !weeklyGoals.contains($0.title) }
        for t in monthData.weeklyGoals { if !weekData.goals.contains(where: { $0.title == t.title }) { weekData.goals.append(Goal(title: t.title, categoryId: t.categoryId)) } }
        coreData.saveWeekData(weekData, for: getCustomWeekInfo(for: date).key)
        
        loadCachedData()
    }
    
    // MARK: - Future Vision
    func loadFutureVisions() { self.futureVisions = coreData.fetchFutureVisions() }
    func addFutureVision(title: String) { futureVisions.append(FutureVision(title: title)); coreData.saveFutureVisions(futureVisions) }
    func removeFutureVision(at offsets: IndexSet) { futureVisions.remove(atOffsets: offsets); coreData.saveFutureVisions(futureVisions) }
    func toggleFutureVisionCompleted(id: UUID) { if let idx = futureVisions.firstIndex(where: { $0.id == id }) { futureVisions[idx].isCompleted.toggle(); coreData.saveFutureVisions(futureVisions) } }
    func addSubTask(to visionId: UUID, title: String) { if let idx = futureVisions.firstIndex(where: { $0.id == visionId }) { futureVisions[idx].subTasks.append(SubTask(title: title)); coreData.saveFutureVisions(futureVisions) } }
    func toggleSubTaskCompleted(visionId: UUID, subTaskId: UUID) { if let vIdx = futureVisions.firstIndex(where: { $0.id == visionId }), let sIdx = futureVisions[vIdx].subTasks.firstIndex(where: { $0.id == subTaskId }) { futureVisions[vIdx].subTasks[sIdx].isCompleted.toggle(); coreData.saveFutureVisions(futureVisions) } }
    func deleteSubTasks(visionId: UUID, at offsets: IndexSet) { if let idx = futureVisions.firstIndex(where: { $0.id == visionId }) { futureVisions[idx].subTasks.remove(atOffsets: offsets); coreData.saveFutureVisions(futureVisions) } }
    
    // MARK: - Settings
    func loadSettings() { if let data = UserDefaults.standard.data(forKey: settingsKey), let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) { self.appSettings = decoded } }
    func saveSettings() { if let encoded = try? JSONEncoder().encode(appSettings) { UserDefaults.standard.set(encoded, forKey: settingsKey) }; NotificationService.shared.updateNotifications(settings: appSettings); objectWillChange.send() }
}
