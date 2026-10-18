import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var palette
    @FocusState private var focused: UUID?

    /// Open tasks, sorted High → Normal → Low. A task being typed stays at the bottom.
    private var openList: [TaskItem] {
        var list = store.openTasks(ui.selection, search: ui.search)
        if let draft = ui.draftID, let i = list.firstIndex(where: { $0.id == draft }) {
            list.append(list.remove(at: i))
        }
        return list
    }

    var body: some View {
        let open = openList
        let closed = store.closedTasks(ui.selection, search: ui.search)

        VStack(alignment: .leading, spacing: 0) {
            header(openCount: open.filter { !$0.title.isEmpty }.count)

            ColumnHeader()
                .padding(.horizontal, 18)
            Rectangle()
                .fill(palette.separator)
                .frame(height: 1)
                .padding(.horizontal, 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if open.isEmpty {
                        EmptyState(allDone: !closed.isEmpty)
                    }
                    ForEach(open) { task in
                        TaskRow(task: task, focus: $focused)
                    }
                    AddTaskRow { ui.newTask(store: store) }

                    if !closed.isEmpty {
                        CompletedSection(tasks: closed, focus: $focused)
                            .padding(.top, 18)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 60)
            }
        }
        .overlay(alignment: .bottom) { undoToast }
        .onAppear { ui.startClickOutsideMonitor() }
        .onExitCommand {
            focused = nil
            ui.showCompleted = false
        }
        .onChange(of: ui.selection) { _, _ in
            ui.showCompleted = false
        }
        .onChange(of: ui.focusRequest) { _, id in
            guard let id else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focused = id
                ui.focusRequest = nil
            }
        }
        .onChange(of: focused) { old, new in
            // Leaving an empty, freshly-added task removes it.
            guard let old, old != new else { return }
            if let t = store.task(old), t.title.trimmingCharacters(in: .whitespaces).isEmpty {
                store.delete(old, undoable: false)
            }
            if ui.draftID == old {
                withAnimation(.easeOut(duration: 0.2)) { ui.draftID = nil }
            }
        }
    }

    // MARK: Header

    private var title: String {
        switch ui.selection {
        case .all: return "All Tasks"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .project(let id): return store.project(id)?.name ?? "Project"
        case .settings: return "Settings"
        }
    }

    private var currentProject: Project? {
        if case .project(let id) = ui.selection { return store.project(id) }
        return nil
    }

    private func header(openCount: Int) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 9) {
                    if let p = currentProject {
                        Circle().fill(Color(hex: p.colorHex)).frame(width: 10, height: 10)
                    }
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                }
                Text(openCount == 1 ? "1 open task" : "\(openCount) open tasks")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            NewTaskButton { ui.newTask(store: store) }
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 16)
    }

    // MARK: Undo toast

    @ViewBuilder
    private var undoToast: some View {
        if let t = store.recentlyDeleted {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                Text("Deleted “\(t.title)”").lineLimit(1)
                Button("Undo") {
                    withAnimation(.easeOut(duration: 0.2)) { store.undoDelete() }
                }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
            }
            .font(.system(size: 12))
            .foregroundStyle(palette.panel)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(palette.primaryText))
            .padding(.bottom, 18)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: t.id) {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if store.recentlyDeleted?.id == t.id {
                    withAnimation(.easeOut(duration: 0.2)) { store.recentlyDeleted = nil }
                }
            }
        }
    }
}

// MARK: - New Task button

struct NewTaskButton: View {
    let action: () -> Void
    @Environment(\.palette) private var palette
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                Text("New Task").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(palette.panel)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(palette.primaryText.opacity(hover ? 0.85 : 1)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("New task (⌘N)")
    }
}

// MARK: - Completed section

struct CompletedSection: View {
    let tasks: [TaskItem]
    var focus: FocusState<UUID?>.Binding

    @EnvironmentObject private var ui: UIState
    @Environment(\.palette) private var palette
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { ui.showCompleted.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(ui.showCompleted ? 90 : 0))
                        .frame(width: 16)
                    Text("Completed")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(tasks.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(palette.pill))
                    Spacer()
                }
                .foregroundStyle(hover || ui.showCompleted ? palette.primaryText : palette.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(hover ? palette.hover : Color.clear))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }

            if ui.showCompleted {
                ForEach(tasks) { task in
                    TaskRow(task: task, focus: focus)
                }
                .transition(.opacity)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { ui.completedFrame = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, frame in ui.completedFrame = frame }
            }
        )
        .onDisappear { ui.completedFrame = .zero }
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let allDone: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: allDone ? "checkmark.circle" : "tray")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(palette.tertiaryText)
            Text(allDone ? "All caught up" : "No tasks here")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.primaryText)
            Text("Press ⌘N or click New Task to add one.")
                .font(.system(size: 12))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
