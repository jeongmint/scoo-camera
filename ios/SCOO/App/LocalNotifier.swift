import Foundation
import UserNotifications

/// Schedules the phone's own notifications (유리병 도착, 아기 편지). Remote pushes need a paid developer team;
/// these do not.
@MainActor
enum LocalNotifier {
    /// Settings switch "유리병·편지 알림".
    static var enabled: Bool { UserDefaults.standard.object(forKey: "localAlerts") as? Bool ?? true }

    /// Asks once, at a moment the user understands (after sending a bottle). Later calls do nothing.
    static func askIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Replaces every scheduled bottle notification with the current plan.
    static func reschedule(_ bottles: [Bottle], real: Bool = false, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(BottleReminders.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard enabled else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        let fast = UserDefaults.standard.bool(forKey: "bottleFastMode")
        for reminder in BottleReminders.plan(bottles, now: now, fast: fast, real: real) {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let seconds = max(1, reminder.date.timeIntervalSince(now))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(BottleReminders.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
    }
}

/// Shows SCOO's notifications as banners even while the app is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
