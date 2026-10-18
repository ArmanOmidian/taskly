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

    init() {}

    // Tolerant decoding so new settings never break an existing data file.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        relativeDates = try c.decodeIfPresent(Bool.self, forKey: .relativeDates) ?? true
        defaultPriorityID = try c.decodeIfPresent(UUID.self, forKey: .defaultPriorityID)
        defaultStatusID = try c.decodeIfPresent(UUID.self, forKey: .defaultStatusID)
        doneStatusID = try c.decodeIfPresent(UUID.self, forKey: .doneStatusID)
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
