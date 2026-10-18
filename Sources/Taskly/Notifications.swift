import Foundation
import AppKit
import UserNotifications

/// Schedules a macOS notification for every open task that has a due date and a reminder.
/// Notifications are delivered by macOS even when Taskly is closed.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let categoryID = "TASKLY_TASK"
    private let doneActionID = "TASKLY_DONE"
    private let snoozeActionID = "TASKLY_SNOOZE"
    private let snoozeSuffix = "-snooze"

    private weak var store: TaskStore?
    private var pendingSync: DispatchWorkItem?

    /// UNUserNotificationCenter only works inside a real .app bundle (crashes otherwise).
    var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }
    private var center: UNUserNotificationCenter? { isAvailable ? UNUserNotificationCenter.current() : nil }

    // MARK: Setup

    func setup(store: TaskStore) {
        self.store = store
        guard let center else { return }
        center.delegate = self

        let done = UNNotificationAction(identifier: doneActionID, title: "Mark as Done", options: [])
        let snooze = UNNotificationAction(identifier: snoozeActionID, title: "Snooze 10 min", options: [])
        let category = UNNotificationCategory(identifier: categoryID, actions: [done, snooze],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])

        requestAuthorization()
        sync(store.data)
    }

    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        guard let center else { completion?(false); return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    /// "Allowed", "Not allowed", "Not asked yet" – for the Settings screen.
    func permissionStatus(_ completion: @escaping (String) -> Void) {
        guard let center else { completion("Unavailable (run the installed app)"); return }
        center.getNotificationSettings { settings in
            let text: String
            switch settings.authorizationStatus {
            case .authorized, .provisional: text = "Allowed"
            case .denied: text = "Not allowed"
            case .notDetermined: text = "Not asked yet"
            default: text = "Allowed"
            }
            DispatchQueue.main.async { completion(text) }
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    func sendTest() {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Taskly"
        content.body = "Notifications are working."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: "taskly-test-\(UUID().uuidString)", content: content, trigger: trigger))
    }

    // MARK: Scheduling

    /// Called on every data change; batched so typing doesn't reschedule on each keystroke.
    func scheduleSync(_ data: AppData) {
        pendingSync?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.sync(data) }
        pendingSync = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    static func fireDate(for task: TaskItem, allDayMinutes: Int) -> Date? {
        guard let due = task.dueDate, let offset = task.reminder.offset else { return nil }
        let base: Date
        if task.dueHasTime {
            base = due
        } else {
            let cal = Calendar.current
            base = cal.date(byAdding: .minute, value: allDayMinutes, to: cal.startOfDay(for: due)) ?? due
        }
        return base.addingTimeInterval(-offset)
    }

    func sync(_ data: AppData) {
        guard let center else { return }
        let closed = Set(data.statuses.filter(\.isClosed).map(\.id))
        let projects = Dictionary(uniqueKeysWithValues: data.projects.map { ($0.id, $0.name) })
        let now = Date()

        var requests: [UNNotificationRequest] = []
        if data.settings.notificationsEnabled {
            for task in data.tasks where !closed.contains(task.statusID) && !task.title.isEmpty {
                guard let fire = Self.fireDate(for: task, allDayMinutes: data.settings.allDayReminderMinutes),
                      fire > now, let due = task.dueDate else { continue }

                let content = UNMutableNotificationContent()
                content.title = task.title
                var body = "Due " + DueFormat.label(due, hasTime: task.dueHasTime, relative: true)
                if let pid = task.projectID, let name = projects[pid] { body += " · \(name)" }
                content.body = body
                content.sound = .default
                content.categoryIdentifier = categoryID
                content.userInfo = ["taskID": task.id.uuidString]

                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                requests.append(UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger))
            }
        }

        // Replace everything we scheduled before (but keep snoozed ones).
        let suffix = snoozeSuffix
        let newRequests = requests
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { !$0.hasSuffix(suffix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for r in newRequests { center.add(r) }
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Show banners even while Taskly is in front.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        let idString = content.userInfo["taskID"] as? String
        let action = response.actionIdentifier

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if action == self.doneActionID, let idString, let id = UUID(uuidString: idString),
               let store = self.store, let task = store.task(id), !store.isClosed(task) {
                store.toggleDone(id)
            } else if action == self.snoozeActionID, let idString {
                let snoozed = (content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
                center.add(UNNotificationRequest(identifier: idString + self.snoozeSuffix, content: snoozed, trigger: trigger))
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            completionHandler()
        }
    }
}
