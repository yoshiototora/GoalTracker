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
    @Published var futureVisions: [FutureVision] = []
    @Published var userStats: UserStats = UserStats()
    @Published var dailyAICount: Int = 15
    private let aiCountKey = "ai_count_storage"
    private let aiDateKey = "ai_date_storage"
    private let statsKey = "user_stats_storage"
    
    private let futureVisionsKey = "future_visions_storage"
    private let reflectionsKey = "reflections_storage"
    private let weekConfigsKey = "week_configs_storage"
    private let monthConfigsKey = "month_configs_storage"
    private let settingsKey = "app_settings_storage"
    
    private var saveWorkItem: DispatchWorkItem?
    
    private static let ymdFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }()
    private static let ymFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f }()
    private static let titleDailyFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy年M月d日"; return f }()
    private static let titleWeeklyFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "M/d"; return f }()
    private static let titleMonthlyFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy年M月"; return f }()
    
    init() {
        loadFromDisk()
        loadFutureVisions()
        checkAndResetAICount()
    }
    
    func resetAllData() {
        UserDefaults.standard.removeObject(forKey: reflectionsKey)
        UserDefaults.standard.removeObject(forKey: weekConfigsKey)
        UserDefaults.standard.removeObject(forKey: monthConfigsKey)
        UserDefaults.standard.removeObject(forKey: futureVisionsKey)
        self.reflections = [:]
        self.weekConfigs = [:]
        self.monthConfigs = [:]
        self.futureVisions = []
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
                sum + getNote(for: d).tasks.filter { $0.isCompleted && ($0.title.hasPrefix("昨日のTry: ") || $0.title.hasPrefix("先週のTry: ") || $0.title.hasPrefix("先月のTry: ")) }.count
            }
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
    
    func getYesterdayTryList(for date: Date) -> [String] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        return getNote(for: yesterday).tryList.filter { !$0.isEmpty }
    }
    
    func getLastWeeklyTryList(for date: Date) -> [String] {
            let cal = Calendar.current
            var checkDate = date
            // dateより前の直近の日曜日を探す
            while cal.component(.weekday, from: checkDate) != 1 {
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }
            // もしdateが日曜日当日の場合、今日のTryは「来週」用なので、タスクには「先週の日曜日」のTryを反映する
            if cal.isDate(checkDate, inSameDayAs: date) {
                checkDate = cal.date(byAdding: .day, value: -7, to: checkDate) ?? checkDate
            }
            return getWeekData(for: checkDate).tryList
        }

    // ▼ 追加: 先月末に設定された月次Tryを取得
    func getLastMonthlyTryList(for date: Date) -> [String] {
        let cal = Calendar.current
        let comp = cal.dateComponents([.year, .month], from: date)
        guard let firstDayOfMonth = cal.date(from: comp),
              let lastDayOfPrevMonth = cal.date(byAdding: .day, value: -1, to: firstDayOfMonth) else { return [] }
        return getMonthData(for: lastDayOfPrevMonth).tryList
    }

    func syncGoalsToTasks(for date: Date) {
        var note = getNote(for: date)
        let monthData = getMonthData(for: date)
        
        let currentDailyGoalTitles = monthData.dailyGoals.map { "日次: " + $0.title }
        
        // ① 昨日のTry
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let yesterdayTryTitles = getNote(for: yesterday).tryList.filter { !$0.isEmpty }.map { "昨日のTry: " + $0 }
        
        // ② 先週のTry（直近の日曜日のデータ）
        let lastWeekTryTitles = getLastWeeklyTryList(for: date).filter { !$0.isEmpty }.map { "先週のTry: " + $0 }
        
        // ③ 先月のTry（先月末のデータ）
        let lastMonthTryTitles = getLastMonthlyTryList(for: date).filter { !$0.isEmpty }.map { "先月のTry: " + $0 }
        
        // 全Tryを結合
        let allTryTitles = yesterdayTryTitles + lastWeekTryTitles + lastMonthTryTitles
        
        note.tasks.removeAll { task in
            if task.title.hasPrefix("日次: ") && !task.isCompleted {
                return !currentDailyGoalTitles.contains(task.title)
            }
            if (task.title.hasPrefix("昨日のTry: ") || task.title.hasPrefix("先週のTry: ") || task.title.hasPrefix("先月のTry: ")) && !task.isCompleted {
                return !allTryTitles.contains(task.title)
            }
            return false
        }
        
        for title in currentDailyGoalTitles {
            if !note.tasks.contains(where: { $0.title == title }) { note.tasks.append(Task(title: title)) }
        }
        for title in allTryTitles {
            if !note.tasks.contains(where: { $0.title == title }) { note.tasks.append(Task(title: title)) }
        }
        
        saveNote(note, for: date)
    }

    func syncWeeklyGoals(for date: Date) {
        var weekData = getWeekData(for: date)
        let monthData = getMonthData(for: date)
        let currentWeeklyGoalTitles = monthData.weeklyGoals.map { $0.title }
        
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
    
    func saveFutureVisions() {
        if let encoded = try? JSONEncoder().encode(futureVisions) {
            UserDefaults.standard.set(encoded, forKey: futureVisionsKey)
        }
    }
    
    func loadFutureVisions() {
        if let data = UserDefaults.standard.data(forKey: futureVisionsKey),
           let decoded = try? JSONDecoder().decode([FutureVision].self, from: data) {
            futureVisions = decoded
        }
    }
    
    func calculateDailyStreak(from date: Date = Date()) -> Int {
        var streak = 0
        var checkDate = date
        let cal = Calendar.current
        
        if getDailyCompletionRate(for: checkDate) < 1.0 {
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        
        while getDailyCompletionRate(for: checkDate) == 1.0 && !getNote(for: checkDate).tasks.isEmpty {
            streak += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }
    
    func toggleFutureVisionCompleted(id: UUID) {
        if let index = futureVisions.firstIndex(where: { $0.id == id }) {
            futureVisions[index].isCompleted.toggle()
            saveFutureVisions()
        }
    }
    
    func addSubTask(to visionId: UUID, title: String) {
        if let index = futureVisions.firstIndex(where: { $0.id == visionId }) {
            futureVisions[index].subTasks.append(SubTask(title: title))
            saveFutureVisions()
        }
    }
    
    func toggleSubTaskCompleted(visionId: UUID, subTaskId: UUID) {
        if let vIndex = futureVisions.firstIndex(where: { $0.id == visionId }),
           let sIndex = futureVisions[vIndex].subTasks.firstIndex(where: { $0.id == subTaskId }) {
            futureVisions[vIndex].subTasks[sIndex].isCompleted.toggle()
            saveFutureVisions()
        }
    }
    
    func deleteSubTasks(visionId: UUID, at offsets: IndexSet) {
        if let index = futureVisions.firstIndex(where: { $0.id == visionId }) {
            futureVisions[index].subTasks.remove(atOffsets: offsets)
            saveFutureVisions()
        }
    }
    
    func refundAICount() {
            if dailyAICount < 15 {
                dailyAICount += 1
                UserDefaults.standard.set(dailyAICount, forKey: aiCountKey)
            }
        }
    
// ▼ 修正: completion（終わった時の合図）を受け取れるように追加
    func generateSubTasksFromAI(for visionId: UUID, goalTitle: String, completion: @escaping () -> Void = {}) {
        if dailyAICount <= 0 { completion(); return }
        decreaseAICount()

        let apiKey = Secrets.geminiAPIKey
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { refundAICount(); completion(); return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = "あなたは目標達成アシスタントです。「\(goalTitle)」という目標を達成するための具体的なステップ（サブタスク）を3〜5つ提案してください。タスクとして管理しやすいよう、各ステップは必ず15〜20文字程度の非常に短い簡潔な文章にしてください。回答は必ず以下のJSON配列形式（文字列のリスト）のみで出力し、挨拶や解説などの他の文章は一切含めないでください。\n例: [\"英語のテキストを買う\", \"毎日10分リスニング\", \"ビザの要件を調べる\"]"

        let requestBody: [String: Any] = [
            "contents": [ ["role": "user", "parts": [ ["text": prompt] ] ] ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                DispatchQueue.main.async { self.refundAICount(); completion() }
                return
            }

            guard let data = data, error == nil else {
                DispatchQueue.main.async { self.refundAICount(); completion() }
                return
            }

            DispatchQueue.main.async {
                do {
                    let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    if var aiText = geminiResponse.candidates.first?.content.parts.first?.text {
                        let backticks = String(repeating: "`", count: 3)
                        aiText = aiText.replacingOccurrences(of: backticks + "json", with: "")
                        aiText = aiText.replacingOccurrences(of: backticks, with: "")
                        aiText = aiText.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if let jsonData = aiText.data(using: .utf8),
                           let suggestedTasks = try? JSONDecoder().decode([String].self, from: jsonData) {
                            for taskTitle in suggestedTasks {
                                self.addSubTask(to: visionId, title: taskTitle)
                            }
                        } else {
                            self.refundAICount()
                        }
                    } else {
                        self.refundAICount()
                    }
                } catch {
                    self.refundAICount()
                }
                // 🌟 処理が終わったら必ず合図を出す
                completion()
            }
        }
        task.resume()
    }

        // ▼ 追加・修正: Try具体化のAIメソッド (1.5-flashに変更 ＆ エラーハンドリング)
        func convertTryToTasks(tryText: String, completion: @escaping ([String]?) -> Void) {
            if dailyAICount <= 0 { completion(nil); return }
            decreaseAICount()

            let apiKey = Secrets.geminiAPIKey
            let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
            guard let url = URL(string: endpoint) else { refundAICount(); completion(nil); return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let prompt = "あなたは目標達成アシスタントです。「\(tryText)」という曖昧な改善案（Try）を、明日から実行可能な具体的な日次タスク（15文字以内の簡潔な行動）に1〜3つに分解・変換してください。回答は必ず以下のJSON配列形式のみで出力し、他の文章は一切含めないでください。\n例: [\"23時にスマホのアラームをかける\", \"寝る前に本を5ページ読む\"]"

            let requestBody: [String: Any] = [
                "contents": [ ["role": "user", "parts": [ ["text": prompt] ] ] ]
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    DispatchQueue.main.async { self.refundAICount(); completion(nil) }
                    return
                }

                guard let data = data, error == nil else {
                    DispatchQueue.main.async { self.refundAICount(); completion(nil) }
                    return
                }
                
                DispatchQueue.main.async {
                    do {
                        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                        if var aiText = geminiResponse.candidates.first?.content.parts.first?.text {
                            let backticks = String(repeating: "`", count: 3)
                            aiText = aiText.replacingOccurrences(of: backticks + "json", with: "")
                            aiText = aiText.replacingOccurrences(of: backticks, with: "")
                            aiText = aiText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let jsonData = aiText.data(using: .utf8), let trys = try? JSONDecoder().decode([String].self, from: jsonData) {
                                completion(trys)
                            } else {
                                self.refundAICount(); completion(nil)
                            }
                        } else {
                            self.refundAICount(); completion(nil)
                        }
                    } catch {
                        self.refundAICount(); completion(nil)
                    }
                }
            }.resume()
        }

    func checkAndResetAICount() {
            let todayStr = Self.ymdFormatter.string(from: Date())
            let savedDate = UserDefaults.standard.string(forKey: aiDateKey) ?? ""

            if todayStr != savedDate {
                // 日付が変わっている（または初回起動）場合は15回にリセット
                dailyAICount = 15
                UserDefaults.standard.set(todayStr, forKey: aiDateKey)
                UserDefaults.standard.set(dailyAICount, forKey: aiCountKey)
            } else {
                // 今日すでに使っていれば、保存された回数を読み込む
                if UserDefaults.standard.object(forKey: aiCountKey) != nil {
                    dailyAICount = UserDefaults.standard.integer(forKey: aiCountKey)
                } else {
                    dailyAICount = 15
                }
            }
        }

        func decreaseAICount() {
            if dailyAICount > 0 {
                dailyAICount -= 1
                UserDefaults.standard.set(dailyAICount, forKey: aiCountKey)
            }
        }
    }

