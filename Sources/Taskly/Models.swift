import Foundation

// MARK: - Core models

struct TaskItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var dueDate: Date?
    var priorityID: UUID
    var statusID: UUID
    var projectID: UUID?
    var createdAt: Date = Date()
    var completedAt: Date?
    /// True when the due date includes a specific time (not just a day).
    var dueHasTime: Bool = false
    /// When to send a notification relative to the due date.
    var reminder: Reminder = .none
}

extension TaskItem {
    // Tolerant decoding so older data files (without time/reminder) still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        priorityID = try c.decode(UUID.self, forKey: .priorityID)
        statusID = try c.decode(UUID.self, forKey: .statusID)
        projectID = try c.decodeIfPresent(UUID.self, forKey: .projectID)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        dueHasTime = try c.decodeIfPresent(Bool.self, forKey: .dueHasTime) ?? false
        reminder = try c.decodeIfPresent(Reminder.self, forKey: .reminder) ?? .none
    }
}

/// Notification timing for a task.
enum Reminder: String, Codable, CaseIterable, Identifiable {
    case none, atTime, min5, min15, min30, hour1, day1

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "No reminder"
        case .atTime: return "At due time"
        case .min5: return "5 minutes before"
        case .min15: return "15 minutes before"
        case .min30: return "30 minutes before"
        case .hour1: return "1 hour before"
        case .day1: return "1 day before"
        }
    }

    /// Seconds before the due time, or nil for no reminder.
    var offset: TimeInterval? {
        switch self {
        case .none: return nil
        case .atTime: return 0
        case .min5: return 5 * 60
        case .min15: return 15 * 60
        case .min30: return 30 * 60
        case .hour1: return 60 * 60
        case .day1: return 24 * 60 * 60
        }
    }
}

enum ViewMode: String, Codable, CaseIterable {
    case list, board
}

/// Anything with an editable name + color (priorities, statuses, projects).
protocol Colorable: Identifiable, Equatable where ID == UUID {
    var name: String { get set }
    var colorHex: String { get set }
}

struct Priority: Colorable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
}

struct TaskStatus: Colorable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    /// When true, tasks with this status count as finished and move to "Completed".
    var isClosed: Bool
}

struct Project: Colorable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Settings

struct AppSettings: Codable, Equatable {
    var theme: AppTheme = .system
    var relativeDates: Bool = true
    var defaultPriorityID: UUID?
    var defaultStatusID: UUID?
    /// Status applied when you tick the circle next to a task.
    var doneStatusID: UUID?
    var viewMode: ViewMode = .list
    var notificationsEnabled: Bool = true
    /// Reminder given to newly created tasks.
    var defaultReminder: Reminder = .atTime
    /// For tasks that have a date but no time: when (minutes after midnight) the reminder is based.
    var allDayReminderMinutes: Int = 9 * 60

    init() {}

    // Tolerant decoding so new settings never break an existing data file.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        relativeDates = try c.decodeIfPresent(Bool.self, forKey: .relativeDates) ?? true
        defaultPriorityID = try c.decodeIfPresent(UUID.self, forKey: .defaultPriorityID)
        defaultStatusID = try c.decodeIfPresent(UUID.self, forKey: .defaultStatusID)
        doneStatusID = try c.decodeIfPresent(UUID.self, forKey: .doneStatusID)
        viewMode = try c.decodeIfPresent(ViewMode.self, forKey: .viewMode) ?? .list
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        defaultReminder = try c.decodeIfPresent(Reminder.self, forKey: .defaultReminder) ?? .atTime
        allDayReminderMinutes = try c.decodeIfPresent(Int.self, forKey: .allDayReminderMinutes) ?? 9 * 60
    }
}

// MARK: - Everything that gets saved to disk

struct AppData: Codable, Equatable {
    var tasks: [TaskItem] = []
    var priorities: [Priority] = []   // order = rank, first is highest
    var statuses: [TaskStatus] = []
    var projects: [Project] = []
    var settings = AppSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try c.decodeIfPresent([TaskItem].self, forKey: .tasks) ?? []
        priorities = try c.decodeIfPresent([Priority].self, forKey: .priorities) ?? []
        statuses = try c.decodeIfPresent([TaskStatus].self, forKey: .statuses) ?? []
        projects = try c.decodeIfPresent([Project].self, forKey: .projects) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }

    static func defaultPriorities() -> [Priority] {
        [
            Priority(name: "High", colorHex: "#FF453A"),
            Priority(name: "Normal", colorHex: "#FF9F0A"),
            Priority(name: "Low", colorHex: "#8E8E93"),
        ]
    }

    static func defaultStatuses() -> [TaskStatus] {
        [
            TaskStatus(name: "To Do", colorHex: "#2F6BFF", isClosed: false),
            TaskStatus(name: "Doing", colorHex: "#FFD60A", isClosed: false),
            TaskStatus(name: "Done", colorHex: "#30D158", isClosed: true),
            TaskStatus(name: "Canceled", colorHex: "#FF453A", isClosed: true),
        ]
    }

    /// First-launch sample data (mirrors the original design).
    static func seed() -> AppData {
        var d = AppData()
        d.priorities = defaultPriorities()
        d.statuses = defaultStatuses()
        let viva = Project(name: "Viva", colorHex: "#7C5CFF")
        d.projects = [viva]

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let high = d.priorities[0].id, normal = d.priorities[1].id, low = d.priorities[2].id
        let todo = d.statuses[0].id, doing = d.statuses[1].id, done = d.statuses[2].id

        d.tasks = [
            TaskItem(title: "Call the VoIP provider", dueDate: cal.date(byAdding: .day, value: 3, to: today),
                     priorityID: high, statusID: todo, projectID: viva.id),
            TaskItem(title: "Review the onboarding flow", dueDate: cal.date(byAdding: .day, value: 1, to: today),
                     priorityID: normal, statusID: doing, projectID: viva.id),
            TaskItem(title: "Tidy up the shared drive", dueDate: nil,
                     priorityID: low, statusID: todo, projectID: nil),
            TaskItem(title: "Call the SMS provider", dueDate: today,
                     priorityID: high, statusID: done, projectID: viva.id, completedAt: Date()),
        ]
        d.settings.defaultPriorityID = normal
        d.settings.defaultStatusID = todo
        d.settings.doneStatusID = done
        return d
    }
}

// MARK: - Sidebar navigation

enum SidebarItem: Hashable {
    case all, today, upcoming
    case project(UUID)
    case settings
}
