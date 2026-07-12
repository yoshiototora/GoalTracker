import UserNotifications
import Foundation

class NotificationService {
    static let shared = NotificationService()

    /// 通知許可のリクエスト。
    /// 🌟 修正: OSの許可ダイアログはユーザーが設定画面で通知トグルをONにした
    /// タイミングでのみ表示する(アプリ離脱時などに自動表示しない)。
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    /// 通知の再スケジュール。
    /// 🌟 修正: requestAuthorizationは呼ばず、現在の権限状態を確認して
    /// 通知可能な状態(authorized / provisional / ephemeral)の場合だけ処理する。
    /// 権限がnotDeterminedのままなら何もしない(ダイアログも出さない)。
    func updateNotifications(settings: AppSettings, currentStreak: Int = 0, todayTasks: [Task] = [], yesterdayTrys: [String] = [], hasUncompletedTasks: Bool = true) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { notificationSettings in
            let status = notificationSettings.authorizationStatus
            guard status == .authorized || status == .provisional || status == .ephemeral else { return }
            DispatchQueue.main.async {
                center.removePendingNotificationRequests(withIdentifiers: ["GoalNotification", "ReflectionNotification"])

                if settings.goalNotificationEnabled {
                    let goalMsg = self.generateGoalMessage(streak: currentStreak, tasks: todayTasks, hasUncompleted: hasUncompletedTasks)
                    self.schedule(id: "GoalNotification", title: String(localized: "🟢 今日の目標"), body: goalMsg, time: settings.goalNotificationTime)
                }
                if settings.reflectionNotificationEnabled {
                    let refMsg = self.generateReflectionMessage(yesterdayTrys: yesterdayTrys)
                    self.schedule(id: "ReflectionNotification", title: String(localized: "📝 振り返り"), body: refMsg, time: settings.reflectionNotificationTime)
                }
            }
        }
    }
    
    private func generateGoalMessage(streak: Int, tasks: [Task], hasUncompleted: Bool) -> String {
        if !hasUncompleted && !tasks.isEmpty {
            return String(localized: "いい感じです！今日のタスクはすべて完了しています✨")
        }
        
        var baseMessage = String(localized: "今日のタスク、")
        let uncompletedTasks = tasks.filter { !$0.isCompleted }
        
        if let randomTask = uncompletedTasks.randomElement()?.title {
            baseMessage = String(localized: "今日の「\(randomTask)」")
        }
        
        let actions = [
            String(localized: "1分だけやってみませんか？"),
            String(localized: "1つだけでもOKです！"),
            String(localized: "今なら少しできそうです"),
            String(localized: "まずは少しだけ始めてみましょう")
        ]
        let action = actions.randomElement() ?? String(localized: "1分だけやってみませんか？")
        
        var finalMessage = "\(baseMessage)\n\(action)"
        
        if streak > 0 {
            finalMessage += String(localized: "（今日できれば\(streak + 1)日連続！🔥）")
        }
        
        if Calendar.current.component(.weekday, from: Date()) == 2 {
            return String(localized: "🌱 新しい1週間の始まりです\n\(finalMessage)")
        }
        
        return finalMessage
    }
    
    private func generateReflectionMessage(yesterdayTrys: [String]) -> String {
        let date = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        
        let isLastDayOfMonth: Bool = {
            let nextDay = cal.date(byAdding: .day, value: 1, to: date) ?? date
            return cal.component(.month, from: date) != cal.component(.month, from: nextDay)
        }()
        
        if isLastDayOfMonth {
            return String(localized: "📅 振り返りタイミングです\n今月を少し振り返って、来月に繋げてみませんか？")
        } else if weekday == 1 {
            return String(localized: "☕️ 今週を少し振り返る時間です\n来週に向けて整えてみませんか？")
        }
        
        if let tryItem = yesterdayTrys.filter({ !$0.isEmpty }).randomElement() {
            return String(localized: "昨日のTry「\(tryItem)」\n今日はどうでしたか？")
        }
        
        let genericActions = [
            String(localized: "今日はどんな1日でしたか？"),
            String(localized: "よかったことを1つだけ書いてみませんか？"),
            String(localized: "明日のために、少しだけ振り返ってみましょう")
        ]
        
        return genericActions.randomElement() ?? String(localized: "今日の振り返りをしましょう📝")
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
