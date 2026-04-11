import UserNotifications
import Foundation

class NotificationService {
    static let shared = NotificationService()
    
    func updateNotifications(settings: AppSettings) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    center.removePendingNotificationRequests(withIdentifiers: ["GoalNotification", "ReflectionNotification"])
                    
                    if settings.goalNotificationEnabled {
                        self.schedule(id: "GoalNotification", title: "🟢 今日の目標", body: "今日のタスクを確認しましょう！", time: settings.goalNotificationTime)
                    }
                    if settings.reflectionNotificationEnabled {
                        self.schedule(id: "ReflectionNotification", title: "📝 振り返りの時間", body: "今日のKPTを振り返りましょう！", time: settings.reflectionNotificationTime)
                    }
                }
            }
        }
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
