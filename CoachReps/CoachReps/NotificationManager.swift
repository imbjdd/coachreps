import Foundation
import UserNotifications

enum NotificationManager {
    static let dailyReminderID = "coachreps.daily.reminder"

    static func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    static func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Schedule a daily reminder at the given hour:minute (24h).
    /// Message adapts based on streak status (we keep it generic — the actual streak state is read at fire time by user looking at app).
    static func scheduleDailyReminder(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])

        let content = UNMutableNotificationContent()
        content.title = "C'est l'heure de s'entraîner"
        content.body = "3 minutes. Ne casse pas ton streak."
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let req = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)
        try? await center.add(req)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }
}
