import SwiftUI
import AppKit

/// Holds all app data and saves it to
/// ~/Library/Application Support/Taskly/data.json on every change.
final class TaskStore: ObservableObject {
    @Published var data: AppData {
        didSet {
            save()
            NotificationManager.shared.scheduleSync(data)
        }
    }
    @Published var recentlyDeleted: TaskItem?

    let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Taskly", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("data.json")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(AppData.self, from: raw) {
            data = decoded
        } else {
            data = AppData.seed()
        }
        normalize()
        save()
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try encoder.encode(data).write(to: fileURL, options: .atomic)
        } catch {
            print("Taskly: failed to save – \(error)")
        }
    }

    /// Keeps data consistent (e.g. after deleting a priority that tasks still use).
    func normalize() {
        var d = data
        if d.priorities.isEmpty { d.priorities = AppData.defaultPriorities() }
        if !d.statuses.contains(where: { !$0.isClosed }) {
            d.statuses.insert(TaskStatus(name: "To Do", colorHex: "#2F6BFF", isClosed: false), at: 0)
        }
        if !d.statuses.contains(where: { $0.isClosed }) {
            d.statuses.append(TaskStatus(name: "Done", colorHex: "#30D158", isClosed: true))
        }

        let priorityIDs = Set(d.priorities.map(\.id))
        let statusIDs = Set(d.statuses.map(\.id))
        let projectIDs = Set(d.projects.map(\.id))

        if let id = d.settings.defaultPriorityID, !priorityIDs.contains(id) { d.settings.defaultPriorityID = nil }
        if d.settings.defaultPriorityID == nil {
            d.settings.defaultPriorityID = d.priorities[d.priorities.count / 2].id
        }
        if let id = d.settings.defaultStatusID,
           d.statuses.first(where: { $0.id == id })?.isClosed != false {
            d.settings.defaultStatusID = nil
        }
        if d.settings.defaultStatusID == nil {
            d.settings.defaultStatusID = d.statuses.first(where: { !$0.isClosed })?.id
        }
        if let id = d.settings.doneStatusID,
           d.statuses.first(where: { $0.id == id })?.isClosed != true {
            d.settings.doneStatusID = nil
        }
        if d.settings.doneStatusID == nil {
            d.settings.doneStatusID = d.statuses.first(where: { $0.isClosed })?.id
        }

        let fallbackPriority = d.settings.defaultPriorityID ?? d.priorities[0].id
        let fallbackStatus = d.settings.defaultStatusID ?? d.statuses[0].id
        for i in d.tasks.indices {
            if !priorityIDs.contains(d.tasks[i].priorityID) { d.tasks[i].priorityID = fallbackPriority }
            if !statusIDs.contains(d.tasks[i].statusID) { d.tasks[i].statusID = fallbackStatus }
            if let p = d.tasks[i].projectID, !projectIDs.contains(p) { d.tasks[i].projectID = nil }
        }
        if d != data { data = d }
    }

    // MARK: - Lookups

    var defaultPriorityID: UUID { data.settings.defaultPriorityID ?? data.priorities.first?.id ?? UUID() }
    var defaultStatusID: UUID { data.settings.defaultStatusID ?? data.statuses.first(where: { !$0.isClosed })?.id ?? UUID() }
    var doneStatusID: UUID { data.settings.doneStatusID ?? data.statuses.first(where: { $0.isClosed })?.id ?? UUID() }

    func task(_ id: UUID) -> TaskItem? { data.tasks.first { $0.id == id } }
    func priority(_ id: UUID) -> Priority? { data.priorities.first { $0.id == id } }
    func status(_ id: UUID) -> TaskStatus? { data.statuses.first { $0.id == id } }
    func project(_ id: UUID?) -> Project? {
        guard let id else { return nil }
        return data.projects.first { $0.id == id }
    }
    func isClosed(_ task: TaskItem) -> Bool { status(task.statusID)?.isClosed ?? false }
    func rank(_ priorityID: UUID) -> Int { data.priorities.firstIndex { $0.id == priorityID } ?? Int.max }

    // MARK: - Filtering & sorting

    func matches(_ t: TaskItem, _ item: SidebarItem, search: String) -> Bool {
        let q = search.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty, !t.title.isEmpty, !t.title.localizedCaseInsensitiveContains(q) { return false }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch item {
        case .all, .settings:
            return true
        case .today:
            guard let d = t.dueDate else { return false }
            return cal.startOfDay(for: d) <= today   // includes overdue
        case .upcoming:
            guard let d = t.dueDate else { return false }
            return cal.startOfDay(for: d) > today
        case .project(let id):
            return t.projectID == id
        }
    }

    /// High priority first, then earliest due date, then oldest.
    func sortOpen(_ a: TaskItem, _ b: TaskItem) -> Bool {
        let ra = rank(a.priorityID), rb = rank(b.priorityID)
        if ra != rb { return ra < rb }
        switch (a.dueDate, b.dueDate) {
        case let (x?, y?) where x != y: return x < y
        case (.some, .none): return true
        case (.none, .some): return false
        default: return a.createdAt < b.createdAt
        }
    }

    func openTasks(_ item: SidebarItem, search: String = "") -> [TaskItem] {
        data.tasks
            .filter { !isClosed($0) && matches($0, item, search: search) }
            .sorted(by: sortOpen)
    }

    func closedTasks(_ item: SidebarItem, search: String = "") -> [TaskItem] {
        data.tasks
            .filter { isClosed($0) && matches($0, item, search: search) }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    func openCount(_ item: SidebarItem) -> Int {
        data.tasks.filter { !isClosed($0) && !$0.title.isEmpty && matches($0, item, search: "") }.count
    }

    // MARK: - Task mutations

    @discardableResult
    func addTask(for item: SidebarItem, statusID: UUID? = nil) -> UUID {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var t = TaskItem(title: "", dueDate: nil, priorityID: defaultPriorityID,
                         statusID: statusID ?? defaultStatusID, projectID: nil)
        t.reminder = data.settings.defaultReminder
        if isClosed(t) { t.completedAt = Date() }
        switch item {
        case .today: t.dueDate = today
        case .upcoming: t.dueDate = cal.date(byAdding: .day, value: 1, to: today)
        case .project(let id): t.projectID = id
        default: break
        }
        data.tasks.append(t)
        return t.id
    }

    func update(_ id: UUID, _ change: (inout TaskItem) -> Void) {
        guard let i = data.tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&data.tasks[i])
    }

    func titleBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { self.task(id)?.title ?? "" },
            set: { value in self.update(id) { $0.title = value } }
        )
    }

    func setStatus(_ id: UUID, to statusID: UUID) {
        let closes = status(statusID)?.isClosed ?? false
        update(id) { t in
            t.statusID = statusID
            if closes {
                if t.completedAt == nil { t.completedAt = Date() }
            } else {
                t.completedAt = nil
            }
        }
    }

    func toggleDone(_ id: UUID) {
        guard let t = task(id) else { return }
        setStatus(id, to: isClosed(t) ? defaultStatusID : doneStatusID)
    }

    func delete(_ id: UUID, undoable: Bool = true) {
        guard let i = data.tasks.firstIndex(where: { $0.id == id }) else { return }
        let removed = data.tasks.remove(at: i)
        if undoable && !removed.title.isEmpty { recentlyDeleted = removed }
    }

    func undoDelete() {
        guard let t = recentlyDeleted else { return }
        data.tasks.append(t)
        recentlyDeleted = nil
        normalize()
    }

    func clearCompleted() {
        data.tasks.removeAll { isClosed($0) }
    }

    // MARK: - Settings mutations

    /// A binding to one element of a settings list, looked up by id (safe across deletes).
    func binding<T: Colorable>(_ keyPath: WritableKeyPath<AppData, [T]>, _ item: T) -> Binding<T> {
        Binding(
            get: { self.data[keyPath: keyPath].first { $0.id == item.id } ?? item },
            set: { value in
                if let i = self.data[keyPath: keyPath].firstIndex(where: { $0.id == item.id }) {
                    self.data[keyPath: keyPath][i] = value
                }
            }
        )
    }

    func move<T: Colorable>(_ keyPath: WritableKeyPath<AppData, [T]>, id: UUID, by delta: Int) {
        var list = data[keyPath: keyPath]
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta
        guard list.indices.contains(j) else { return }
        list.swapAt(i, j)
        data[keyPath: keyPath] = list
    }

    func addPriority() {
        data.priorities.append(Priority(name: "New priority", colorHex: ColorPresets.next(after: data.priorities.map(\.colorHex))))
    }

    func deletePriority(_ id: UUID) {
        guard data.priorities.count > 1 else { return }
        var d = data
        d.priorities.removeAll { $0.id == id }
        let fallback = (d.settings.defaultPriorityID != id ? d.settings.defaultPriorityID : nil) ?? d.priorities[0].id
        for i in d.tasks.indices where d.tasks[i].priorityID == id { d.tasks[i].priorityID = fallback }
        data = d
        normalize()
    }

    func addStatus() {
        let s = TaskStatus(name: "New status", colorHex: ColorPresets.next(after: data.statuses.map(\.colorHex)), isClosed: false)
        // Insert before the first "closed" status so open ones stay together.
        if let i = data.statuses.firstIndex(where: { $0.isClosed }) {
            data.statuses.insert(s, at: i)
        } else {
            data.statuses.append(s)
        }
    }

    func canDeleteStatus(_ id: UUID) -> Bool {
        guard let s = status(id) else { return false }
        return data.statuses.filter { $0.isClosed == s.isClosed }.count > 1
    }

    func canToggleClosed(_ id: UUID) -> Bool { canDeleteStatus(id) }

    func deleteStatus(_ id: UUID) {
        guard canDeleteStatus(id), let s = status(id) else { return }
        var d = data
        d.statuses.removeAll { $0.id == id }
        let fallback = d.statuses.first { $0.isClosed == s.isClosed }?.id ?? d.statuses[0].id
        for i in d.tasks.indices where d.tasks[i].statusID == id { d.tasks[i].statusID = fallback }
        data = d
        normalize()
    }

    @discardableResult
    func addProject(name: String) -> UUID {
        let p = Project(name: name, colorHex: ColorPresets.next(after: data.projects.map(\.colorHex)))
        data.projects.append(p)
        return p.id
    }

    func deleteProject(_ id: UUID) {
        var d = data
        d.projects.removeAll { $0.id == id }
        for i in d.tasks.indices where d.tasks[i].projectID == id { d.tasks[i].projectID = nil }
        data = d
    }
}

// MARK: - UI state shared between views

final class UIState: ObservableObject {
    @Published var selection: SidebarItem = .all
    @Published var showCompleted = false
    @Published var search = ""
    /// Task whose title field should get keyboard focus.
    @Published var focusRequest: UUID?
    /// A freshly added task stays at the bottom of the list until you finish typing it.
    @Published var draftID: UUID?

    /// Frame of the Completed section (window coordinates) – used for "click outside to close".
    var completedFrame: CGRect = .zero
    private var clickMonitor: Any?

    func newTask(store: TaskStore, statusID: UUID? = nil) {
        if selection == .settings { selection = .all }
        showCompleted = false
        let id = store.addTask(for: selection, statusID: statusID)
        draftID = id
        focusRequest = id
    }

    func startClickOutsideMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleClick(event)
            return event
        }
    }

    private func handleClick(_ event: NSEvent) {
        guard showCompleted,
              let window = event.window,
              window.canBecomeMain,                 // ignore clicks inside popovers
              let content = window.contentView else { return }
        let p = event.locationInWindow
        let point = CGPoint(x: p.x, y: content.bounds.height - p.y)   // flip to top-left origin
        if !completedFrame.contains(point) {
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.18)) { self.showCompleted = false }
            }
        }
    }
}
