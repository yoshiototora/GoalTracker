//
//  GoalViewModel.swift
//  GoalTracker
//

import SwiftUI
import Combine

class GoalViewModel: ObservableObject {
    @Published var selectedDate: Date = Date() { didSet { loadCachedData() } }
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
    
    init() { loadSettings(); loadFutureVisions(); loadCachedData() }
    
    private func sortTasks(_ tasks: inout [Task]) {
        tasks.sort { t1, t2 in
            if t1.type != t2.type {
                let priority: [TaskType: Int] = [.dailyGoal: 0, .tryCarryOver: 1, .normal: 2]
                return (priority[t1.type] ?? 3) < (priority[t2.type] ?? 3)
            }
            return t1.id.uuidString < t2.id.uuidString
        }
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
    
    func getNote(for date: Date) -> DailyNote {
        var note = coreData.fetchDailyNote(for: dateKey(date))
        sortTasks(&note.tasks)
        return note
    }
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
        sortTasks(&note.tasks)
        coreData.saveDailyNote(note, for: dateKey(date))
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
        currentDailyStreak = calculateDailyStreak()
    }
    func toggleTask(id: UUID, for date: Date) {
        var note = getNote(for: date)
        if let idx = note.tasks.firstIndex(where: { $0.id == id }) {
            note.tasks[idx].isCompleted.toggle()
            sortTasks(&note.tasks)
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
    func editTask(id: UUID, newTitle: String, newCategoryId: String, for date: Date) {
        var note = getNote(for: date)
        if let idx = note.tasks.firstIndex(where: { $0.id == id }) {
            note.tasks[idx].title = newTitle
            note.tasks[idx].categoryId = newCategoryId
            sortTasks(&note.tasks)
            coreData.saveDailyNote(note, for: dateKey(date))
            if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
        }
    }
    
    // MARK: - KPT Updates
    enum ReflectionField { case keep, problem, reflection }
    
    func updateDailyNote(_ text: String, field: ReflectionField, date: Date) {
        var note = getNote(for: date)
        if field == .keep { note.keep = text }
        else if field == .problem { note.problem = text }
        // 💡 追加：日次の「自由記述」を保存できるように分岐を追加
        else if field == .reflection { note.reflection = text }
        
        coreData.saveDailyNote(note, for: dateKey(date))
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
    }
    
    func updateDailyTryList(_ list: [Goal], date: Date) {
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
    func updateWeeklyTryList(_ list: [Goal], date: Date) {
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
    func updateMonthlyTryList(_ list: [Goal], date: Date) {
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
    func getValidDates(from dates: [Date]) -> [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return dates.filter { Calendar.current.startOfDay(for: $0) <= today }
    }
    func getWeeklyDailyAvgRate(for date: Date) -> Double {
        let dates = getValidDates(from: getCustomWeekInfo(for: date).dates)
        guard !dates.isEmpty else { return 0 }
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
        let dates = getValidDates(from: getMonthDates(for: date))
        guard !dates.isEmpty else { return 0 }
        return dates.map { getDailyCompletionRate(for: $0) }.reduce(0, +) / Double(dates.count)
    }
    func getMonthlyWeeklyGoalAvgRate(for date: Date) -> Double {
        let dates = getValidDates(from: getMonthDates(for: date)); var weekKeys = Set<String>()
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
    func getWeeklyTotalRate(for date: Date) -> Double { return (getWeeklyDailyAvgRate(for: date) + getWeeklyGoalRate(for: date)) / 2.0 }
    func getMonthlyTotalRate(for date: Date) -> Double { return (getMonthlyDailyAvgRate(for: date) + getMonthlyWeeklyGoalAvgRate(for: date) + getMonthlyGoalRate(for: date)) / 3.0 }

    func getComparisonText(for date: Date, isWeekly: Bool) -> String {
        let targetDates = isWeekly ? getCustomWeekInfo(for: date).dates : getMonthDates(for: date)
        let validDates = getValidDates(from: targetDates)
        let isFuture = validDates.isEmpty
        let isOngoing = validDates.count > 0 && validDates.count < targetDates.count
        if isFuture { return "これからの目標✨" }
        let target = isWeekly ? "先週" : "先月"
        if isOngoing {
            let currentPace = isWeekly ? getWeeklyDailyAvgRate(for: date) : getMonthlyDailyAvgRate(for: date)
            let prevDate = Calendar.current.date(byAdding: isWeekly ? .day : .month, value: isWeekly ? -7 : -1, to: date) ?? date
            let prevPace = isWeekly ? getWeeklyDailyAvgRate(for: prevDate) : getMonthlyDailyAvgRate(for: prevDate)
            let diff = Int(round((currentPace - prevPace) * 100))
            if diff > 0 { return "\(target)より ＋\(diff)%ペース🔥" } else if diff < 0 { return "\(target)より \(diff)%ペース🏃" } else { return "\(target)と同じペース✨" }
        } else {
            let currentRate = isWeekly ? getWeeklyTotalRate(for: date) : getMonthlyTotalRate(for: date)
            let prevDate = Calendar.current.date(byAdding: isWeekly ? .day : .month, value: isWeekly ? -7 : -1, to: date) ?? date
            let prevRate = isWeekly ? getWeeklyTotalRate(for: prevDate) : getMonthlyTotalRate(for: prevDate)
            let diff = Int(round((currentRate - prevRate) * 100))
            if diff > 0 { return "\(target)比 ＋\(diff)%🎉" } else if diff < 0 { return "\(target)比 \(diff)%📉" } else { return "\(target)と同じペース✨" }
        }
    }
    
    // MARK: - Sync Engine
    func syncAll(for date: Date) {
        var note = getNote(for: date); let monthData = getMonthData(for: date)
        let dailyGoalTitles = monthData.dailyGoals.map { $0.title }
        let allTrys = getYesterdayTryList(for: date).map{"昨日のTry: "+$0}
        
        note.tasks.removeAll { ($0.type == .dailyGoal && !dailyGoalTitles.contains($0.title)) || ($0.type == .tryCarryOver && !allTrys.contains($0.title)) }
        for g in monthData.dailyGoals {
            if let idx = note.tasks.firstIndex(where: { $0.title == g.title && $0.type == .dailyGoal }) { note.tasks[idx].categoryId = g.categoryId }
            else { note.tasks.append(Task(title: g.title, type: .dailyGoal, categoryId: g.categoryId)) }
        }
        for t in allTrys { if !note.tasks.contains(where: { $0.title == t && $0.type == .tryCarryOver }) { note.tasks.append(Task(title: t, type: .tryCarryOver)) } }
        
        sortTasks(&note.tasks)
        coreData.saveDailyNote(note, for: dateKey(date))
        
        var weekData = getWeekData(for: date); let weeklyGoalTitles = monthData.weeklyGoals.map { $0.title }
        weekData.goals.removeAll { !weeklyGoalTitles.contains($0.title) }
        for t in monthData.weeklyGoals { if !weekData.goals.contains(where: { $0.title == t.title }) { weekData.goals.append(Goal(title: t.title, categoryId: t.categoryId)) } }
        coreData.saveWeekData(weekData, for: getCustomWeekInfo(for: date).key)
        loadCachedData()
    }
    
    // MARK: - Baton Support
    func getYesterdayTryList(for date: Date) -> [String] { return getNote(for: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date).tryList.map { $0.title } }
    func getLastWeeklyTryList(for date: Date) -> [Goal] {
        var checkDate = date; let cal = Calendar.current; while cal.component(.weekday, from: checkDate) != 1 { checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate }
        if cal.isDate(checkDate, inSameDayAs: date) { checkDate = cal.date(byAdding: .day, value: -7, to: checkDate) ?? checkDate }
        return getWeekData(for: checkDate).tryList
    }
    func getLastMonthlyTryList(for date: Date) -> [Goal] {
        let cal = Calendar.current; guard let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: date)), let prevLast = cal.date(byAdding: .day, value: -1, to: firstDay) else { return [] }
        return getMonthData(for: prevLast).tryList
    }
    func getPreviousWeekDate(from date: Date) -> Date { return Calendar.current.date(byAdding: .day, value: -7, to: date) ?? date }
    func getPreviousMonthDate(from date: Date) -> Date {
        let cal = Calendar.current; guard let first = cal.date(from: cal.dateComponents([.year, .month], from: date)) else { return date }
        return cal.date(byAdding: .day, value: -1, to: first) ?? date
    }

    func getCategory(id: String) -> CategoryItem { return appSettings.categories.first(where: { $0.id == id }) ?? CategoryItem(id: "none", name: "指定なし", colorName: "gray") }
    func loadFutureVisions() { self.futureVisions = coreData.fetchFutureVisions() }
    func addFutureVision(title: String) { futureVisions.append(FutureVision(title: title)); coreData.saveFutureVisions(futureVisions) }
    func removeFutureVision(at offsets: IndexSet) { futureVisions.remove(atOffsets: offsets); coreData.saveFutureVisions(futureVisions) }
    func toggleFutureVisionCompleted(id: UUID) { if let idx = futureVisions.firstIndex(where: { $0.id == id }) { futureVisions[idx].isCompleted.toggle(); coreData.saveFutureVisions(futureVisions) } }
    func addSubTask(to visionId: UUID, title: String) { if let idx = futureVisions.firstIndex(where: { $0.id == visionId }) { futureVisions[idx].subTasks.append(SubTask(title: title)); coreData.saveFutureVisions(futureVisions) } }
    func toggleSubTaskCompleted(visionId: UUID, subTaskId: UUID) { if let vIdx = futureVisions.firstIndex(where: { $0.id == visionId }), let sIdx = futureVisions[vIdx].subTasks.firstIndex(where: { $0.id == subTaskId }) { futureVisions[vIdx].subTasks[sIdx].isCompleted.toggle(); coreData.saveFutureVisions(futureVisions) } }
    func deleteSubTasks(visionId: UUID, at offsets: IndexSet) { if let idx = futureVisions.firstIndex(where: { $0.id == visionId }) { futureVisions[idx].subTasks.remove(atOffsets: offsets); coreData.saveFutureVisions(futureVisions) } }
    func loadSettings() { if let data = UserDefaults.standard.data(forKey: settingsKey), let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) { self.appSettings = decoded } }
    func saveSettings() { if let encoded = try? JSONEncoder().encode(appSettings) { UserDefaults.standard.set(encoded, forKey: settingsKey) }; refreshNotifications(); objectWillChange.send() }
    func refreshNotifications() {
        let today = Date(); let note = getNote(for: today); let hasUncompleted = note.tasks.isEmpty ? true : note.tasks.contains(where: { !$0.isCompleted })
        NotificationService.shared.updateNotifications(settings: appSettings, currentStreak: currentDailyStreak, todayTasks: note.tasks, yesterdayTrys: getYesterdayTryList(for: today), hasUncompletedTasks: hasUncompleted)
    }
}
