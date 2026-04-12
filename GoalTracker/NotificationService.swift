import UserNotifications
import Foundation

class NotificationService {
    static let shared = NotificationService()
    
    // 👇 ここが最新版（引数が5つ）になっていることでエラーが消えます
    func updateNotifications(settings: AppSettings, currentStreak: Int = 0, todayTasks: [Task] = [], yesterdayTrys: [String] = [], hasUncompletedTasks: Bool = true) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    center.removePendingNotificationRequests(withIdentifiers: ["GoalNotification", "ReflectionNotification"])
                    
                    if settings.goalNotificationEnabled {
                        let goalMsg = self.generateGoalMessage(streak: currentStreak, tasks: todayTasks, hasUncompleted: hasUncompletedTasks)
                        self.schedule(id: "GoalNotification", title: "🟢 今日の目標", body: goalMsg, time: settings.goalNotificationTime)
                    }
                    if settings.reflectionNotificationEnabled {
                        let refMsg = self.generateReflectionMessage(yesterdayTrys: yesterdayTrys)
                        self.schedule(id: "ReflectionNotification", title: "📝 振り返り", body: refMsg, time: settings.reflectionNotificationTime)
                    }
                }
            }
        }
    }
    
    // MARK: - 🎯 目標通知の生成
    private func generateGoalMessage(streak: Int, tasks: [Task], hasUncompleted: Bool) -> String {
        if !hasUncompleted && !tasks.isEmpty {
            return "いい感じです！今日のタスクはすべて完了しています✨"
        }
        
        var baseMessage = "今日のタスク、"
        let uncompletedTasks = tasks.filter { !$0.isCompleted }
        
        if let randomTask = uncompletedTasks.randomElement()?.title {
            baseMessage = "今日の「\(randomTask)」"
        }
        
        let actions = [
            "1分だけやってみませんか？",
            "1つだけでOKです！",
            "今やってしまいましょう🏃‍♂️",
            "少しだけ手をつけてみませんか？"
        ]
        let action = actions.randomElement() ?? "1分だけやってみませんか？"
        
        var finalMessage = "\(baseMessage)\n\(action)"
        
        if streak > 0 {
            finalMessage += "（今日やれば\(streak + 1)日連続！🔥）"
        }
        
        if Calendar.current.component(.weekday, from: Date()) == 2 {
            return "🌱 週のスタート！\n\(finalMessage)"
        }
        
        return finalMessage
    }
    
    // MARK: - 📝 振り返り通知の生成
    private func generateReflectionMessage(yesterdayTrys: [String]) -> String {
        let date = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        
        let isLastDayOfMonth: Bool = {
            let nextDay = cal.date(byAdding: .day, value: 1, to: date) ?? date
            return cal.component(.month, from: date) != cal.component(.month, from: nextDay)
        }()
        
        if isLastDayOfMonth {
            return "📅 振り返りタイミング！\n今月の記録を整理して来月に備えましょう。"
        } else if weekday == 1 {
            return "☕️ 週末の振り返りタイミング！\n今週を少し振り返って、来週に繋げてみませんか？"
        }
        
        if let tryItem = yesterdayTrys.filter({ !$0.isEmpty }).randomElement() {
            return "昨日のTry「\(tryItem)」\n今日はどうでしたか？1分でメモ📝"
        }
        
        let genericActions = [
            "1分で終わります。今日のKPTを書きませんか？",
            "完璧じゃなくてOK。今日できたこと（Keep）を1つメモ！",
            "今日できなかったことは、明日のTryにすれば大丈夫💡"
        ]
        
        return genericActions.randomElement() ?? "今日の振り返りをしましょう📝"
    }
    
    private func schedule(id: String, title: String, body: String, time: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
