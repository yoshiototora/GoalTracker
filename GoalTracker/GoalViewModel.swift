import SwiftUI
import Combine
import WidgetKit

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
    
    private func sortTasks(_ tasks: inout [Task], for date: Date) {
        let monthData = coreData.fetchMonthData(for: monthKey(date))
        let dailyGoalTitles = monthData.dailyGoals.map { $0.title }
        let prevDate = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let prevNote = coreData.fetchDailyNote(for: dateKey(prevDate))
        let yesterdayTryList = prevNote.tryList.map { $0.title }
        
        tasks.sort { t1, t2 in
            if t1.isCompleted != t2.isCompleted {
                        return !t1.isCompleted && t2.isCompleted
                    }
            if t1.type != t2.type {
                let priority: [TaskType: Int] = [.dailyGoal: 0, .tryCarryOver: 1, .normal: 2]
                return (priority[t1.type] ?? 3) < (priority[t2.type] ?? 3)
            }
            if t1.type == .dailyGoal {
                let idx1 = dailyGoalTitles.firstIndex(of: t1.title) ?? 999
                let idx2 = dailyGoalTitles.firstIndex(of: t2.title) ?? 999
                if idx1 != idx2 { return idx1 < idx2 }
            } else if t1.type == .tryCarryOver {
                let idx1 = yesterdayTryList.firstIndex(of: t1.title) ?? 999
                let idx2 = yesterdayTryList.firstIndex(of: t2.title) ?? 999
                if idx1 != idx2 { return idx1 < idx2 }
            }
            return t1.id.uuidString < t2.id.uuidString
        }
    }
    
    // MARK: - Keys & Titles
        func dateKey(_ date: Date) -> String { return ymdFormatter.string(from: date) }
        func monthKey(_ date: Date) -> String { return ymFormatter.string(from: date) }
        
        func getCustomWeekInfo(for date: Date) -> (key: String, dates: [Date]) {
            var cal = Calendar.current
            cal.firstWeekday = (appSettings.weeklyReflectionWeekday % 7) + 1
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            guard let startOfWeek = cal.date(from: comps) else { return ("", []) }
            var targetWeekDates: [Date] = []
            for i in 0..<7 {
                if let d = cal.date(byAdding: .day, value: i, to: startOfWeek) { targetWeekDates.append(d) }
            }
            let year = comps.yearForWeekOfYear ?? cal.component(.year, from: date)
            let week = comps.weekOfYear ?? 1
            let key = String(format: "%04d-W%02d", year, week)
            return (key, targetWeekDates)
        }
        
        // 🌟 以下の3つを「端末の言語に自動で合わせる」書き方に修正
        func getDailyTitle(for date: Date) -> String {
            return date.formatted(.dateTime.year().month().day())
        }
        
        // 🌟 修正：表示する期間を月内に収めるオプションを追加
        func getWeeklyTitle(for date: Date, restrictedToMonthOf monthDate: Date? = nil) -> String {
            var dates = getCustomWeekInfo(for: date).dates
            
            // 指定された月がある場合、その月の日付だけに絞り込む
            if let limitMonthDate = monthDate {
                let cal = Calendar.current
                let targetMonth = cal.component(.month, from: limitMonthDate)
                let targetYear = cal.component(.year, from: limitMonthDate)
                dates = dates.filter {
                    cal.component(.month, from: $0) == targetMonth &&
                    cal.component(.year, from: $0) == targetYear
                }
            }
            
            guard let first = dates.first, let last = dates.last else { return "" }
            
            // 1日しかない場合はその日だけ、複数日ある場合は範囲を表示
            if first == last {
                return first.formatted(.dateTime.month().day())
            } else {
                return "\(first.formatted(.dateTime.month().day())) - \(last.formatted(.dateTime.month().day()))"
            }
        }
        
        func getMonthlyTitle(for date: Date) -> String {
            return date.formatted(.dateTime.year().month())
        }
    
    func getNote(for date: Date) -> DailyNote {
        var note = coreData.fetchDailyNote(for: dateKey(date))
        sortTasks(&note.tasks, for: date)
        return note
    }
    func getWeekData(for date: Date) -> WeekData { return coreData.fetchWeekData(for: getCustomWeekInfo(for: date).key) }
    func getMonthData(for date: Date) -> MonthData { return coreData.fetchMonthData(for: monthKey(date)) }
    
    func loadCachedData() {
        currentDailyNote = getNote(for: selectedDate)
        currentWeekData = getWeekData(for: selectedDate)
        currentMonthData = getMonthData(for: selectedDate)
        
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        var comps = Calendar.current.dateComponents([.year, .month], from: nextMonth)
        comps.day = 1
        let firstDayOfNextMonth = Calendar.current.date(from: comps) ?? nextMonth
        nextMonthData = getMonthData(for: firstDayOfNextMonth)
        
        currentDailyStreak = calculateDailyStreak()
    }
    
    // MARK: - Tasks Updates
    func addTask(title: String, for date: Date) {
        var note = getNote(for: date); note.tasks.append(Task(title: title, type: .normal))
        sortTasks(&note.tasks, for: date)
        coreData.saveDailyNote(note, for: dateKey(date))
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
        currentDailyStreak = calculateDailyStreak()
        WidgetCenter.shared.reloadAllTimelines()
    }
    func toggleTask(id: UUID, for date: Date) {
        var note = getNote(for: date)
        if let idx = note.tasks.firstIndex(where: { $0.id == id }) {
            note.tasks[idx].isCompleted.toggle()
            sortTasks(&note.tasks, for: date)
            coreData.saveDailyNote(note, for: dateKey(date))
            if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
            
            // 完了状態の変更を振り返り画面のTryリスト（翌日への引き継ぎ）に即座に反映させる
            carryOverUncompletedTries(for: date)
            
            currentDailyStreak = calculateDailyStreak()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    func removeTasks(at offsets: IndexSet, for date: Date) {
        var note = getNote(for: date); note.tasks.remove(atOffsets: offsets)
        coreData.saveDailyNote(note, for: dateKey(date))
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
        currentDailyStreak = calculateDailyStreak()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func editTask(id: UUID, newTitle: String, newCategoryId: String, for date: Date) {
        var note = getNote(for: date)
        if let idx = note.tasks.firstIndex(where: { $0.id == id }) {
            let taskType = note.tasks[idx].type
            let oldTitle = note.tasks[idx].title
            
            note.tasks[idx].title = newTitle
            note.tasks[idx].categoryId = newCategoryId
            sortTasks(&note.tasks, for: date)
            coreData.saveDailyNote(note, for: dateKey(date))
            
            if taskType == .dailyGoal {
                var mData = getMonthData(for: date)
                if let mIdx = mData.dailyGoals.firstIndex(where: { $0.title == oldTitle }) {
                    mData.dailyGoals[mIdx].title = newTitle
                    mData.dailyGoals[mIdx].categoryId = newCategoryId
                    coreData.saveMonthData(mData, for: monthKey(date))
                }
            } else if taskType == .tryCarryOver {
                let prevDate = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                var prevNote = getNote(for: prevDate)
                let cleanTitle = oldTitle
                
                if let tIdx = prevNote.tryList.firstIndex(where: { $0.title == cleanTitle }) {
                    prevNote.tryList[tIdx].title = newTitle
                    prevNote.tryList[tIdx].categoryId = newCategoryId
                    coreData.saveDailyNote(prevNote, for: dateKey(prevDate))
                }
            }
            loadCachedData()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // MARK: - KPT Updates
    enum ReflectionField { case keep, problem, reflection }
    func updateDailyNote(_ text: String, field: ReflectionField, date: Date) {
        var note = getNote(for: date)
        if field == .keep { note.keep = text } else if field == .problem { note.problem = text } else if field == .reflection { note.reflection = text }
        coreData.saveDailyNote(note, for: dateKey(date))
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) { currentDailyNote = note }
    }
    func updateDailyTryList(_ list: [Goal], date: Date) {
        var note = getNote(for: date); note.tryList = list
        coreData.saveDailyNote(note, for: dateKey(date))
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        syncAll(for: tomorrow)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func carryOverUncompletedTries(for date: Date) {
        var note = getNote(for: date)
        var modified = false
        
        // Rule 1: 今日完了したTryタスクは明日のtryList（引き継ぎ用）から完全に除外する
        let completedTries = note.tasks.filter { $0.type == .tryCarryOver && $0.isCompleted }
        for task in completedTries {
            if note.tryList.contains(where: { $0.title == task.title }) {
                note.tryList.removeAll(where: { $0.title == task.title })
                modified = true
            }
        }
        
        // Rule 2: 今日未完了のTryタスクを抽出（ただし3日連続未完了のものは自動引き継ぎ対象外にする）
        let uncompletedTries = note.tasks.filter { $0.type == .tryCarryOver && !$0.isCompleted }
        for task in uncompletedTries {
            let isOverdue = consecutiveUncompletedCount(for: task.title, startingFrom: date) >= 3
            if isOverdue {
                continue // 3回連続未完了のTryは自動引き継ぎをスキップ（保留）
            }
            
            if !note.tryList.contains(where: { $0.title == task.title }) {
                let newGoal = Goal(title: task.title, isCompleted: false, categoryId: task.categoryId, startDate: date)
                note.tryList.append(newGoal)
                modified = true
            }
        }
        
        if modified {
            coreData.saveDailyNote(note, for: dateKey(date))
            if Calendar.current.isDate(date, inSameDayAs: selectedDate) {
                currentDailyNote = note
            }
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
            syncAll(for: tomorrow)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func consecutiveUncompletedCount(for title: String, startingFrom date: Date) -> Int {
        var count = 0
        var checkDate = date
        let cal = Calendar.current
        
        for _ in 0..<3 {
            let note = getNote(for: checkDate)
            if let task = note.tasks.first(where: { $0.title == title }) {
                if task.type == .tryCarryOver && !task.isCompleted {
                    count += 1
                } else {
                    break
                }
            } else {
                break
            }
            guard let prevDate = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDate
        }
        return count
    }
    
    func getOverdueTries(for date: Date) -> [String] {
        let note = getNote(for: date)
        let uncompletedTries = note.tasks.filter { $0.type == .tryCarryOver && !$0.isCompleted }
        
        var overdue: [String] = []
        for task in uncompletedTries {
            if note.tryList.contains(where: { $0.title == task.title }) {
                continue // すでに継続を選択済みの場合は除外
            }
            if consecutiveUncompletedCount(for: task.title, startingFrom: date) >= 3 {
                overdue.append(task.title)
            }
        }
        return overdue
    }
    
    func continueOverdueTry(title: String, for date: Date) {
        var note = getNote(for: date)
        let categoryId = note.tasks.first(where: { $0.title == title })?.categoryId ?? "none"
        
        if !note.tryList.contains(where: { $0.title == title }) {
            let newGoal = Goal(title: title, isCompleted: false, categoryId: categoryId, startDate: date)
            note.tryList.append(newGoal)
            coreData.saveDailyNote(note, for: dateKey(date))
            
            if Calendar.current.isDate(date, inSameDayAs: selectedDate) {
                currentDailyNote = note
            }
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
            syncAll(for: tomorrow)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func convertToProblem(title: String, for date: Date) {
        var note = getNote(for: date)
        
        // 1. 今日のProblemテキストに追記
        let prefix = note.problem.isEmpty ? "" : "\n"
        let bullet = "- \(title)"
        note.problem += "\(prefix)\(bullet)"
        
        // 2. 今日のタスクタイプを.normalに変更して、自動引き継ぎ/未完了判定の対象外にする
        if let idx = note.tasks.firstIndex(where: { $0.title == title && $0.type == .tryCarryOver }) {
            note.tasks[idx].type = .normal
        }
        
        // 3. Tryリストから削除
        note.tryList.removeAll(where: { $0.title == title })
        
        coreData.saveDailyNote(note, for: dateKey(date))
        
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) {
            currentDailyNote = note
        }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        syncAll(for: tomorrow)
        WidgetCenter.shared.reloadAllTimelines()
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
        syncAll(for: date)
        WidgetCenter.shared.reloadAllTimelines()
    }
    func updateWeeklyTryList(_ list: [Goal], date: Date) {
        var data = getWeekData(for: date); data.tryList = list
        coreData.saveWeekData(data, for: getCustomWeekInfo(for: date).key)
        syncAll(for: date)
        WidgetCenter.shared.reloadAllTimelines()
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
        coreData.saveMonthData(data, for: monthKey(date))
        
        // 🌟 修正: .weekly の場合も月全体を同期するように変更
        if field == .daily || field == .weekly {
            syncEntireMonth(for: date)
        } else {
            syncAll(for: date)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func updateMonthlyTryList(_ list: [Goal], date: Date) {
        var data = getMonthData(for: date); data.tryList = list
        coreData.saveMonthData(data, for: monthKey(date))
        syncAll(for: date)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Calculations
    func calculateDailyStreak() -> Int {
        var streak = 0; var checkDate = selectedDate; let cal = Calendar.current
        while true { let tasks = getNote(for: checkDate).tasks; if tasks.isEmpty || !tasks.allSatisfy({ $0.isCompleted }) { break }; streak += 1; checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate }
        return streak
    }
    func getDailyCompletionRate(for date: Date) -> Double { let tasks = getNote(for: date).tasks; guard !tasks.isEmpty else { return 0.0 }; return Double(tasks.filter { $0.isCompleted }.count) / Double(tasks.count) }
    func getValidDates(from dates: [Date]) -> [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        let start = appSettings.appStartDate.map { Calendar.current.startOfDay(for: $0) } ?? Date.distantPast
        return dates.filter { let d = Calendar.current.startOfDay(for: $0); return d <= today && d >= start }
    }
    // 🌟 修正: restrictedToMonthOf パラメータを追加
    func getWeeklyDailyAvgRate(for date: Date, restrictedToMonthOf monthDate: Date? = nil) -> Double {
        var dates = getValidDates(from: getCustomWeekInfo(for: date).dates)
        
        // 指定された月の日付のみに絞り込む
        if let limitMonthDate = monthDate {
            let cal = Calendar.current
            let targetMonth = cal.component(.month, from: limitMonthDate)
            let targetYear = cal.component(.year, from: limitMonthDate)
            dates = dates.filter {
                cal.component(.month, from: $0) == targetMonth &&
                cal.component(.year, from: $0) == targetYear
            }
        }
        
        guard !dates.isEmpty else { return 0 }
        return dates.map { getDailyCompletionRate(for: $0) }.reduce(0, +) / Double(dates.count)
    }
    func getWeeklyGoalRate(for date: Date) -> Double? {
        let goals = getWeekData(for: date).goals; guard !goals.isEmpty else { return nil }
        return Double(goals.filter { $0.isCompleted }.count) / Double(goals.count)
    }
    func getMonthDates(for date: Date) -> [Date] { let cal = Calendar.current; guard let range = cal.range(of: .day, in: .month, for: date), let start = cal.date(from: cal.dateComponents([.year, .month], from: date)) else { return [] }; return (0..<range.count).compactMap { cal.date(byAdding: .day, value: $0, to: start) } }
    func getValidWeekKeys(for monthDate: Date) -> [String] {
        let allDates = getMonthDates(for: monthDate); let start = appSettings.appStartDate.map { Calendar.current.startOfDay(for: $0) } ?? Date.distantPast
        var keysInOrder = [String](); var daysCount: [String: Int] = [:]
        for d in allDates { if Calendar.current.startOfDay(for: d) < start { continue }; let key = getCustomWeekInfo(for: d).key; if daysCount[key] == nil { keysInOrder.append(key) }; daysCount[key, default: 0] += 1 }
        if appSettings.skipShortFirstWeek, let firstKey = keysInOrder.first { if let count = daysCount[firstKey], count <= appSettings.shortWeekThreshold { keysInOrder.removeFirst() } }
        if appSettings.skipShortLastWeek, let lastKey = keysInOrder.last { if let count = daysCount[lastKey], count <= appSettings.shortLastWeekThreshold { keysInOrder.removeLast() } }
        return keysInOrder
    }
    func getMonthlyDailyAvgRate(for date: Date) -> Double { let dates = getValidDates(from: getMonthDates(for: date)); guard !dates.isEmpty else { return 0 }; return dates.map { getDailyCompletionRate(for: $0) }.reduce(0, +) / Double(dates.count) }
    func getMonthlyWeeklyGoalAvgRate(for date: Date) -> Double? {
        let validDates = getValidDates(from: getMonthDates(for: date)); let validKeysForMonth = getValidWeekKeys(for: date)
        var weekKeys = Set<String>(); for d in validDates { let key = getCustomWeekInfo(for: d).key; if validKeysForMonth.contains(key) { weekKeys.insert(key) } }
        var validRates: [Double] = []; for key in weekKeys { let goals = coreData.fetchWeekData(for: key).goals; if !goals.isEmpty { validRates.append(Double(goals.filter { $0.isCompleted }.count) / Double(goals.count)) } }
        return validRates.isEmpty ? nil : validRates.reduce(0, +) / Double(validRates.count)
    }
    func getMonthlyGoalRate(for date: Date) -> Double? {
        let goals = getMonthData(for: date).monthlyGoals; guard !goals.isEmpty else { return nil }
        return Double(goals.filter { $0.isCompleted }.count) / Double(goals.count)
    }
    // 完了タスク数のカウントを月で制限可能にする
    func getCompletedTasksCount(for date: Date, isWeekly: Bool, restrictedToMonthOf monthDate: Date? = nil) -> Int {
        let dates = isWeekly ? getCustomWeekInfo(for: date).dates : getMonthDates(for: date)
        var validDates = getValidDates(from: dates)
        
        // 🌟 追加：月またぎの場合、指定された月の日付のみに絞り込む
        if isWeekly, let limitMonthDate = monthDate {
            let cal = Calendar.current
            let targetMonth = cal.component(.month, from: limitMonthDate)
            let targetYear = cal.component(.year, from: limitMonthDate)
            validDates = validDates.filter {
                cal.component(.month, from: $0) == targetMonth &&
                cal.component(.year, from: $0) == targetYear
            }
        }
        
        return validDates.reduce(0) { sum, d in sum + getNote(for: d).tasks.filter { $0.isCompleted }.count }
    }

    // Try実行数のカウントを月で制限可能にする
    func getTryExecutionCount(for date: Date, isWeekly: Bool, restrictedToMonthOf monthDate: Date? = nil) -> Int {
        let dates = isWeekly ? getCustomWeekInfo(for: date).dates : getMonthDates(for: date)
        var validDates = getValidDates(from: dates)
        
        // 🌟 追加：月またぎの場合、指定された月の日付のみに絞り込む
        if isWeekly, let limitMonthDate = monthDate {
            let cal = Calendar.current
            let targetMonth = cal.component(.month, from: limitMonthDate)
            let targetYear = cal.component(.year, from: limitMonthDate)
            validDates = validDates.filter {
                cal.component(.month, from: $0) == targetMonth &&
                cal.component(.year, from: $0) == targetYear
            }
        }
        
        return validDates.reduce(0) { sum, d in sum + getNote(for: d).tasks.filter { $0.isCompleted && $0.type == .tryCarryOver }.count }
    }
    func getWeeklyTotalRate(for date: Date) -> Double { let r1 = getWeeklyDailyAvgRate(for: date); if let r2 = getWeeklyGoalRate(for: date) { return (r1 + r2) / 2.0 }; return r1 }
    func getMonthlyTotalRate(for date: Date) -> Double { let r1 = getMonthlyDailyAvgRate(for: date); var total = r1; var count = 1.0; if let r2 = getMonthlyWeeklyGoalAvgRate(for: date) { total += r2; count += 1.0 }; if let r3 = getMonthlyGoalRate(for: date) { total += r3; count += 1.0 }; return total / count }

    func getComparisonText(for date: Date, isWeekly: Bool) -> String {
        let targetDates = isWeekly ? getCustomWeekInfo(for: date).dates : getMonthDates(for: date); let validDates = getValidDates(from: targetDates)
        let isFuture = validDates.isEmpty; let isOngoing = validDates.count > 0 && validDates.count < targetDates.count
        if isFuture { return String(localized: "これからの目標✨") }
        let target = isWeekly ? String(localized: "先週") : String(localized: "先月")
        if isOngoing {
            let currentPace = isWeekly ? getWeeklyDailyAvgRate(for: date) : getMonthlyDailyAvgRate(for: date); let prevDate = Calendar.current.date(byAdding: isWeekly ? .day : .month, value: isWeekly ? -7 : -1, to: date) ?? date; let prevPace = isWeekly ? getWeeklyDailyAvgRate(for: prevDate) : getMonthlyDailyAvgRate(for: prevDate)
            let diff = Int(round((currentPace - prevPace) * 100))
            if diff > 0 { return String(localized: "\(target)より ＋\(diff)%ペース🔥") } else if diff < 0 { return String(localized: "\(target)より \(diff)%ペース🏃") } else { return String(localized: "\(target)と同じペース✨") }
        } else {
            let currentRate = isWeekly ? getWeeklyTotalRate(for: date) : getMonthlyTotalRate(for: date); let prevDate = Calendar.current.date(byAdding: isWeekly ? .day : .month, value: isWeekly ? -7 : -1, to: date) ?? date; let prevRate = isWeekly ? getWeeklyTotalRate(for: prevDate) : getMonthlyTotalRate(for: prevDate)
            let diff = Int(round((currentRate - prevRate) * 100))
            if diff > 0 { return String(localized: "\(target)比 ＋\(diff)%🎉") } else if diff < 0 { return String(localized: "\(target)比 \(diff)%📉") } else { return String(localized: "\(target)と同じペース✨") }
        }
    }
    
    // MARK: - 同期システム
    func syncAll(for date: Date, shouldLoadCache: Bool = true) {
        var note = getNote(for: date)
        var monthData = getMonthData(for: date)
        var isMonthChanged = false
        
        let targetDate = Calendar.current.startOfDay(for: date)
        
        let validDailyTitles = monthData.dailyGoals
            .filter { Calendar.current.startOfDay(for: $0.startDate) <= targetDate }
            .map { $0.title }
            
        // 昨日のタスクから完了済みのTryタスクのタイトルを抽出して除外ガードをかける
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let yesterdayNote = getNote(for: yesterday)
        let yesterdayCompletedTryTitles = yesterdayNote.tasks.filter { $0.type == .tryCarryOver && $0.isCompleted }.map { $0.title }
        
        let yesterdayTryGoals = getYesterdayTryGoals(for: date).filter { goal in
            !yesterdayCompletedTryTitles.contains(goal.title)
        }
        let allTryTitles = yesterdayTryGoals.map { $0.title }
        
        note.tasks.removeAll { ($0.type == .dailyGoal && !validDailyTitles.contains($0.title)) || ($0.type == .tryCarryOver && !allTryTitles.contains($0.title)) }
        
        for (i, g) in monthData.dailyGoals.enumerated() {
            if Calendar.current.startOfDay(for: g.startDate) > targetDate { continue }
            
            if let idx = note.tasks.firstIndex(where: { $0.title == g.title && $0.type == .dailyGoal }) {
                if note.tasks[idx].categoryId != "none" && g.categoryId == "none" {
                    monthData.dailyGoals[i].categoryId = note.tasks[idx].categoryId
                    isMonthChanged = true
                } else if g.categoryId != "none" {
                    note.tasks[idx].categoryId = g.categoryId
                }
            } else {
                note.tasks.append(Task(title: g.title, type: .dailyGoal, categoryId: g.categoryId))
            }
        }
        
        for tryGoal in yesterdayTryGoals {
            let taskTitle = tryGoal.title
            if let idx = note.tasks.firstIndex(where: { $0.title == taskTitle && $0.type == .tryCarryOver }) {
                if tryGoal.categoryId != "none" { note.tasks[idx].categoryId = tryGoal.categoryId }
            } else {
                note.tasks.append(Task(title: taskTitle, type: .tryCarryOver, categoryId: tryGoal.categoryId))
            }
        }
        
        if isMonthChanged { coreData.saveMonthData(monthData, for: monthKey(date)) }
        sortTasks(&note.tasks, for: date)
        coreData.saveDailyNote(note, for: dateKey(date))
        
        var weekData = getWeekData(for: date)
        let validWeeklyTitles = monthData.weeklyGoals
            .filter { Calendar.current.startOfDay(for: $0.startDate) <= targetDate }
            .map { $0.title }
            
        weekData.goals.removeAll { !validWeeklyTitles.contains($0.title) }
        
        for t in monthData.weeklyGoals {
            if Calendar.current.startOfDay(for: t.startDate) > targetDate { continue }
            
            if let idx = weekData.goals.firstIndex(where: { $0.title == t.title }) {
                if t.categoryId != "none" { weekData.goals[idx].categoryId = t.categoryId }
            } else {
                weekData.goals.append(Goal(title: t.title, categoryId: t.categoryId, startDate: t.startDate))
            }
        }
        coreData.saveWeekData(weekData, for: getCustomWeekInfo(for: date).key)
        
        if shouldLoadCache { loadCachedData() }
    }
    
    func syncEntireMonth(for date: Date) {
        let dates = getMonthDates(for: date)
        for d in dates { syncAll(for: d, shouldLoadCache: false) }
        loadCachedData()
    }
    
    // MARK: - Baton Support
    func getYesterdayTryList(for date: Date) -> [String] { return getNote(for: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date).tryList.map { $0.title } }
    func getLastWeeklyTryList(for date: Date) -> [Goal] { let prevWeekDate = Calendar.current.date(byAdding: .day, value: -7, to: date) ?? date; return getWeekData(for: prevWeekDate).tryList }
    func getLastMonthlyTryList(for date: Date) -> [Goal] { let cal = Calendar.current; guard let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: date)), let prevLast = cal.date(byAdding: .day, value: -1, to: firstDay) else { return [] }; return getMonthData(for: prevLast).tryList }
    func getPreviousWeekDate(from date: Date) -> Date { return Calendar.current.date(byAdding: .day, value: -7, to: date) ?? date }
    func getPreviousMonthDate(from date: Date) -> Date { let cal = Calendar.current; guard let first = cal.date(from: cal.dateComponents([.year, .month], from: date)) else { return date }; return cal.date(byAdding: .day, value: -1, to: first) ?? date }
    func getCategory(id: String) -> CategoryItem { return appSettings.categories.first(where: { $0.id == id }) ?? CategoryItem(id: "none", name: String(localized: "指定なし"), colorName: "gray") }
    func getYesterdayTryGoals(for date: Date) -> [Goal] { return getNote(for: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date).tryList }
    
    // MARK: - Future Vision
    func loadFutureVisions() { self.futureVisions = coreData.fetchFutureVisions() }
    func addFutureVision(title: String) { futureVisions.append(FutureVision(title: title)); coreData.saveFutureVisions(futureVisions) }
    func removeFutureVision(at offsets: IndexSet) { futureVisions.remove(atOffsets: offsets); coreData.saveFutureVisions(futureVisions) }
    func toggleFutureVisionCompleted(id: UUID) { if let idx = futureVisions.firstIndex(where: { $0.id == id }) { futureVisions[idx].isCompleted.toggle(); coreData.saveFutureVisions(futureVisions) } }
    func updateFutureVision(id: UUID, title: String) { if let idx = futureVisions.firstIndex(where: { $0.id == id }) { futureVisions[idx].title = title; coreData.saveFutureVisions(futureVisions) } }
    func addSubTask(to visionId: UUID, title: String) { if let idx = futureVisions.firstIndex(where: { $0.id == visionId }) { futureVisions[idx].subTasks.append(SubTask(title: title)); coreData.saveFutureVisions(futureVisions) } }
    func toggleSubTaskCompleted(visionId: UUID, subTaskId: UUID) { if let vIdx = futureVisions.firstIndex(where: { $0.id == visionId }), let sIdx = futureVisions[vIdx].subTasks.firstIndex(where: { $0.id == subTaskId }) { futureVisions[vIdx].subTasks[sIdx].isCompleted.toggle(); coreData.saveFutureVisions(futureVisions) } }
    func deleteSubTasks(visionId: UUID, at offsets: IndexSet) { if let idx = futureVisions.firstIndex(where: { $0.id == visionId }) { futureVisions[idx].subTasks.remove(atOffsets: offsets); coreData.saveFutureVisions(futureVisions) } }
    func updateSubTask(visionId: UUID, subTaskId: UUID, title: String) { if let vIdx = futureVisions.firstIndex(where: { $0.id == visionId }), let sIdx = futureVisions[vIdx].subTasks.firstIndex(where: { $0.id == subTaskId }) { futureVisions[vIdx].subTasks[sIdx].title = title; coreData.saveFutureVisions(futureVisions) } }
    
    // MARK: - Notifications & Settings
    func loadSettings() { if let data = UserDefaults.standard.data(forKey: settingsKey), let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) { self.appSettings = decoded } }
    func saveSettings() { if let encoded = try? JSONEncoder().encode(appSettings) { UserDefaults.standard.set(encoded, forKey: settingsKey) }; refreshNotifications(); objectWillChange.send() }
    func refreshNotifications() { let today = Date(); let note = getNote(for: today); let hasUncompleted = note.tasks.isEmpty ? true : note.tasks.contains(where: { !$0.isCompleted }); NotificationService.shared.updateNotifications(settings: appSettings, currentStreak: currentDailyStreak, todayTasks: note.tasks, yesterdayTrys: getYesterdayTryList(for: today), hasUncompletedTasks: hasUncompleted) }

    // MARK: - Individual Goal Progress
    func getDailyGoalProgress(goal: Goal, for date: Date, isWeekly: Bool, restrictedToMonthOf monthDate: Date? = nil) -> String {
        let dates = isWeekly ? getCustomWeekInfo(for: date).dates : getMonthDates(for: date)
        var validDates = getValidDates(from: dates).filter {
            Calendar.current.startOfDay(for: $0) >= Calendar.current.startOfDay(for: goal.startDate)
        }
        
        // 🌟 追加：月またぎの場合、指定された月の日付のみに絞り込む
        if isWeekly, let limitMonthDate = monthDate {
            let cal = Calendar.current
            let targetMonth = cal.component(.month, from: limitMonthDate)
            let targetYear = cal.component(.year, from: limitMonthDate)
            validDates = validDates.filter {
                cal.component(.month, from: $0) == targetMonth &&
                cal.component(.year, from: $0) == targetYear
            }
        }
        
        guard !validDates.isEmpty else { return "-/-" }
        let completed = validDates.filter { d in getNote(for: d).tasks.contains(where: { $0.title == goal.title && $0.type == .dailyGoal && $0.isCompleted }) }.count
        let rate = Int((Double(completed) / Double(validDates.count)) * 100)
        return String(localized: "\(completed)/\(validDates.count)回 (\(rate)%)")
    }
    
    func getWeeklyGoalProgress(goal: Goal, for monthDate: Date) -> String {
        let validDates = getValidDates(from: getMonthDates(for: monthDate)).filter {
            Calendar.current.startOfDay(for: $0) >= Calendar.current.startOfDay(for: goal.startDate)
        }
        let validKeysForMonth = getValidWeekKeys(for: monthDate)
        var passedWeekKeys = Set<String>(); for d in validDates { let key = getCustomWeekInfo(for: d).key; if validKeysForMonth.contains(key) { passedWeekKeys.insert(key) } }
        guard !passedWeekKeys.isEmpty else { return "-/-" }
        let completed = passedWeekKeys.filter { key in coreData.fetchWeekData(for: key).goals.contains(where: { $0.title == goal.title && $0.isCompleted }) }.count
        let rate = Int((Double(completed) / Double(passedWeekKeys.count)) * 100); return String(localized: "\(completed)/\(passedWeekKeys.count)週 (\(rate)%)")
    }
    
    func getDailyGoalsProgressStats(for date: Date, isWeekly: Bool, restrictedToMonthOf monthDate: Date? = nil) -> [(String, String)] {
        let df = DateFormatter(); df.dateFormat = "M/d"
        let targetDate = Calendar.current.startOfDay(for: date)
        return getMonthData(for: date).dailyGoals
            .filter { Calendar.current.startOfDay(for: $0.startDate) <= targetDate }
            .map { goal in
                let datePrefix = goal.startDate > Date.distantPast ? "\(df.string(from: goal.startDate))〜 " : ""
                // 🌟 修正：引数を getDailyGoalProgress に渡す
                return ("\(datePrefix)\(goal.title)", getDailyGoalProgress(goal: goal, for: date, isWeekly: isWeekly, restrictedToMonthOf: monthDate))
            }
    }
    
    func getWeeklyGoalsProgressStats(for date: Date) -> [(String, String)] {
        let targetDate = Calendar.current.startOfDay(for: date)
        return getMonthData(for: date).weeklyGoals
            .filter { Calendar.current.startOfDay(for: $0.startDate) <= targetDate }
            .map { ($0.title, getWeeklyGoalProgress(goal: $0, for: date)) }
    }
}
