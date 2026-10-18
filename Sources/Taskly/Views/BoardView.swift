import SwiftUI

/// Kanban board: one column per status. Drag cards between columns to change their status.
struct BoardView: View {
    let tasks: [TaskItem]
    var focus: FocusState<UUID?>.Binding
    @Binding var editingID: UUID?

    @EnvironmentObject private var store: TaskStore

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(store.data.statuses) { status in
                    BoardColumn(
                        status: status,
                        tasks: tasks.filter { $0.statusID == status.id }.sorted(by: store.sortOpen),
                        focus: focus,
                        editingID: $editingID
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .padding(.bottom, 20)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .scrollIndicators(.automatic)
    }
}

struct BoardColumn: View {
    let status: TaskStatus
    let tasks: [TaskItem]
    var focus: FocusState<UUID?>.Binding
    @Binding var editingID: UUID?

    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var palette
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: status.colorHex)).frame(width: 8, height: 8)
                Text(status.name.isEmpty ? "Untitled" : status.name)
                    .font(.jakarta(13, .semibold))
                    .foregroundStyle(palette.primaryText)
                Text("\(tasks.filter { !$0.title.isEmpty }.count)")
                    .font(.jakarta(11, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(palette.pill))
                Spacer()
                IconButton(systemName: "plus", help: "Add task to \(status.name)") {
                    ui.newTask(store: store, statusID: status.id)
                }
            }
            .padding(.horizontal, 4)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        BoardCard(task: task, focus: focus, editingID: $editingID)
                    }
                    if tasks.isEmpty {
                        Text(targeted ? "Drop here" : "No tasks")
                            .font(.jakarta(12))
                            .foregroundStyle(palette.tertiaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 22)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(palette.separator, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            )
                    }
                    AddCardButton { ui.newTask(store: store, statusID: status.id) }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)
        }
        .padding(10)
        .frame(width: 280)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(targeted ? palette.pill : palette.inset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(targeted ? Color(hex: status.colorHex).opacity(0.7) : palette.separator,
                              lineWidth: targeted ? 1.5 : 1)
        )
        .dropDestination(for: String.self) { items, _ in
            var moved = false
            for item in items {
                if let id = UUID(uuidString: item), let t = store.task(id), t.statusID != status.id {
                    withAnimation(.easeOut(duration: 0.2)) { store.setStatus(id, to: status.id) }
                    moved = true
                }
            }
            return moved
        } isTargeted: { targeted = $0 }
        .animation(.easeOut(duration: 0.15), value: targeted)
    }
}

struct BoardCard: View {
    let task: TaskItem
    var focus: FocusState<UUID?>.Binding
    @Binding var editingID: UUID?

    @EnvironmentObject private var store: TaskStore
    @Environment(\.palette) private var palette
    @State private var hover = false

    private var isEditing: Bool { editingID == task.id || task.title.isEmpty }

    var body: some View {
        if isEditing {
            card
        } else {
            card
                .draggable(task.id.uuidString) {
                    Text(task.title)
                        .font(.jakarta(13, .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(palette.panel))
                }
        }
    }

    private var card: some View {
        let closed = store.isClosed(task)
        let status = store.status(task.statusID)
        let priority = store.priority(task.priorityID)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                CheckCircle(
                    closed: closed,
                    color: Color(hex: status?.colorHex ?? "#30D158"),
                    isCancel: closed && task.statusID != store.doneStatusID
                ) {
                    withAnimation(.easeOut(duration: 0.2)) { store.toggleDone(task.id) }
                }
                .padding(.top, 1)

                if isEditing {
                    TextField("Task name", text: store.titleBinding(task.id), axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.jakarta(13, .medium))
                        .focused(focus, equals: task.id)
                        .onSubmit {
                            editingID = nil
                            focus.wrappedValue = nil
                        }
                } else {
                    Text(task.title)
                        .font(.jakarta(13, .medium))
                        .strikethrough(closed, color: palette.tertiaryText)
                        .foregroundStyle(closed ? palette.tertiaryText : palette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture(count: 2) { startEditing() }
                        .help("Double-click to rename")
                }
            }

            HStack(spacing: 2) {
                OptionPicker(
                    options: store.data.priorities.map { OptionItem(id: $0.id, name: $0.name, color: Color(hex: $0.colorHex)) },
                    selected: task.priorityID,
                    muted: closed
                ) { id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.2)) { store.update(task.id) { $0.priorityID = id } }
                }
                .help(priority.map { "Priority: \($0.name)" } ?? "Priority")

                DueDatePicker(date: task.dueDate, hasTime: task.dueHasTime,
                              relative: store.data.settings.relativeDates, muted: closed) { newDate, hasTime in
                    store.update(task.id) {
                        $0.dueDate = newDate
                        $0.dueHasTime = hasTime
                    }
                }
                Spacer(minLength: 0)
            }
            .font(.jakarta(12))
            .padding(.leading, 18)

            HStack(spacing: 2) {
                OptionPicker(
                    options: [OptionItem(id: nil, name: "No project", color: nil)]
                        + store.data.projects.map { OptionItem(id: $0.id, name: $0.name, color: Color(hex: $0.colorHex)) },
                    selected: task.projectID,
                    placeholder: "No project",
                    muted: closed
                ) { id in
                    store.update(task.id) { $0.projectID = id }
                }
                Spacer(minLength: 0)
                ReminderButton(reminder: task.reminder, hasDate: task.dueDate != nil) { r in
                    store.update(task.id) { $0.reminder = r }
                }
                .opacity(hover || (task.reminder != .none && task.dueDate != nil) ? 1 : 0)
                IconButton(systemName: "trash", help: "Delete task", destructive: true) {
                    withAnimation(.easeOut(duration: 0.2)) { store.delete(task.id) }
                }
                .opacity(hover ? 1 : 0)
            }
            .font(.jakarta(12))
            .padding(.leading, 18)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(palette.panel)
                .shadow(color: .black.opacity(hover ? 0.08 : 0.04), radius: hover ? 6 : 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(palette.separator)
        )
        .contentShape(RoundedRectangle(cornerRadius: 11))
        .onHover { hover = $0 }
    }

    private func startEditing() {
        editingID = task.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focus.wrappedValue = task.id }
    }
}

struct AddCardButton: View {
    let action: () -> Void
    @Environment(\.palette) private var palette
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("Add task")
                    .font(.jakarta(12, .medium))
                Spacer()
            }
            .foregroundStyle(hover ? palette.primaryText : palette.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 10).fill(hover ? palette.hover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
