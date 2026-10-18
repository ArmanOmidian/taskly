import SwiftUI

struct ColumnHeader: View {
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Col.check)
            Text("Title").frame(maxWidth: .infinity, alignment: .leading)
            Text("Due date").padding(.leading, 8).frame(width: Col.due, alignment: .leading)
            Text("Priority").padding(.leading, 8).frame(width: Col.priority, alignment: .leading)
            Text("Project").padding(.leading, 8).frame(width: Col.project, alignment: .leading)
            Text("Status").padding(.leading, 8).frame(width: Col.status, alignment: .leading)
            Text("Actions").frame(width: Col.actions, alignment: .center)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(palette.primaryText)
        .padding(.horizontal, 10)
        .frame(height: 34)
    }
}

struct TaskRow: View {
    let task: TaskItem
    var focus: FocusState<UUID?>.Binding

    @EnvironmentObject private var store: TaskStore
    @Environment(\.palette) private var palette
    @State private var hover = false

    var body: some View {
        let closed = store.isClosed(task)
        let status = store.status(task.statusID)

        HStack(spacing: 0) {
            CheckCircle(
                closed: closed,
                color: Color(hex: status?.colorHex ?? "#30D158"),
                isCancel: closed && task.statusID != store.doneStatusID
            ) {
                withAnimation(.easeOut(duration: 0.2)) { store.toggleDone(task.id) }
            }
            .frame(width: Col.check, alignment: .leading)

            TextField("Task name", text: store.titleBinding(task.id))
                .textFieldStyle(.plain)
                .focused(focus, equals: task.id)
                .onSubmit { focus.wrappedValue = nil }
                .strikethrough(closed, color: palette.tertiaryText)
                .foregroundStyle(closed ? palette.tertiaryText : palette.primaryText)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            DueDatePicker(date: task.dueDate, relative: store.data.settings.relativeDates, muted: closed) { newDate in
                store.update(task.id) { $0.dueDate = newDate }
            }
            .frame(width: Col.due, alignment: .leading)

            OptionPicker(
                options: store.data.priorities.map { OptionItem(id: $0.id, name: $0.name, color: Color(hex: $0.colorHex)) },
                selected: task.priorityID,
                muted: closed
            ) { id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) { store.update(task.id) { $0.priorityID = id } }
            }
            .frame(width: Col.priority, alignment: .leading)

            OptionPicker(
                options: [OptionItem(id: nil, name: "No project", color: nil)]
                    + store.data.projects.map { OptionItem(id: $0.id, name: $0.name, color: Color(hex: $0.colorHex)) },
                selected: task.projectID,
                muted: closed
            ) { id in
                store.update(task.id) { $0.projectID = id }
            }
            .frame(width: Col.project, alignment: .leading)

            OptionPicker(
                options: store.data.statuses.map { OptionItem(id: $0.id, name: $0.name, color: Color(hex: $0.colorHex)) },
                selected: task.statusID,
                muted: closed
            ) { id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) { store.setStatus(task.id, to: id) }
            }
            .frame(width: Col.status, alignment: .leading)

            IconButton(systemName: "trash", help: "Delete task", destructive: true) {
                withAnimation(.easeOut(duration: 0.2)) { store.delete(task.id) }
            }
            .opacity(hover ? 1 : 0.55)
            .frame(width: Col.actions, alignment: .center)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 9).fill(hover ? palette.hover : Color.clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

struct AddTaskRow: View {
    let action: () -> Void
    @Environment(\.palette) private var palette
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16, height: 16)
                    .frame(width: Col.check, alignment: .leading)
                Text("Add task")
                    .font(.system(size: 13))
                Spacer()
            }
            .foregroundStyle(hover ? palette.primaryText : palette.secondaryText)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 9).fill(hover ? palette.hover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
