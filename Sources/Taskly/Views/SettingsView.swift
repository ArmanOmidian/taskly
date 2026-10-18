import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.palette) private var palette
    @State private var confirmClear = false
    @State private var permission = "…"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.jakarta(22, .semibold))
                        .foregroundStyle(palette.primaryText)
                    Text("Customize how Taskly looks and works. Changes save automatically.")
                        .font(.jakarta(12))
                        .foregroundStyle(palette.secondaryText)
                }

                appearance
                notifications
                priorities
                statuses
                projects
                defaults
                dataSection
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Sections

    private var appearance: some View {
        SettingsSection(title: "Appearance", icon: "paintpalette") {
            SettingRow(title: "Theme") {
                Picker("", selection: $store.data.settings.theme) {
                    ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
            }
            RowDivider()
            SettingRow(title: "Relative due dates", caption: "Show “3 Days” instead of “Oct 21”.") {
                Toggle("", isOn: $store.data.settings.relativeDates)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }

    private var notifications: some View {
        SettingsSection(title: "Notifications", icon: "bell",
                        caption: "Taskly reminds you about open tasks with a due date. Reminders arrive even when the app is closed.") {
            SettingRow(title: "Enable reminders") {
                Toggle("", isOn: $store.data.settings.notificationsEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            RowDivider()
            SettingRow(title: "Default reminder", caption: "Given to every new task. Change it per task with the bell icon.") {
                Picker("", selection: $store.data.settings.defaultReminder) {
                    ForEach(Reminder.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .frame(width: 180)
            }
            RowDivider()
            SettingRow(title: "Time for tasks without a time", caption: "Reminders for date-only tasks are based on this time.") {
                DatePicker("", selection: allDayTimeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.stepperField)
                    .labelsHidden()
            }
            RowDivider()
            SettingRow(title: "macOS permission", caption: permission) {
                HStack(spacing: 8) {
                    Button("Send test") { NotificationManager.shared.sendTest() }
                    Button("Open System Settings") { NotificationManager.shared.openSystemSettings() }
                }
            }
        }
        .onAppear {
            NotificationManager.shared.requestAuthorization { _ in
                NotificationManager.shared.permissionStatus { permission = $0 }
            }
        }
    }

    private var allDayTimeBinding: Binding<Date> {
        Binding(
            get: {
                let m = store.data.settings.allDayReminderMinutes
                return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
            },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                store.data.settings.allDayReminderMinutes = (c.hour ?? 9) * 60 + (c.minute ?? 0)
            }
        )
    }

    private var priorities: some View {
        SettingsSection(title: "Priorities", icon: "flag",
                        caption: "Tasks are sorted by this order — the top one is the highest priority.") {
            ForEach(Array(store.data.priorities.enumerated()), id: \.element.id) { index, p in
                if index > 0 { RowDivider() }
                EditableRow(
                    item: store.binding(\.priorities, p),
                    canMoveUp: index > 0,
                    canMoveDown: index < store.data.priorities.count - 1,
                    canDelete: store.data.priorities.count > 1,
                    onMove: { store.move(\.priorities, id: p.id, by: $0) },
                    onDelete: { store.deletePriority(p.id) },
                    extra: { EmptyView() }
                )
            }
            RowDivider()
            AddRowButton(title: "Add priority") { store.addPriority() }
        }
    }

    private var statuses: some View {
        SettingsSection(title: "Statuses", icon: "circle.dashed",
                        caption: "Statuses marked “Completes task” move tasks into the Completed section.") {
            ForEach(Array(store.data.statuses.enumerated()), id: \.element.id) { index, s in
                if index > 0 { RowDivider() }
                EditableRow(
                    item: store.binding(\.statuses, s),
                    canMoveUp: index > 0,
                    canMoveDown: index < store.data.statuses.count - 1,
                    canDelete: store.canDeleteStatus(s.id),
                    onMove: { store.move(\.statuses, id: s.id, by: $0) },
                    onDelete: { store.deleteStatus(s.id) },
                    extra: {
                        Toggle("Completes task", isOn: closedBinding(s))
                            .toggleStyle(.checkbox)
                            .font(.jakarta(12))
                            .foregroundStyle(palette.secondaryText)
                            .disabled(!store.canToggleClosed(s.id))
                    }
                )
            }
            RowDivider()
            AddRowButton(title: "Add status") { store.addStatus() }
        }
    }

    private var projects: some View {
        SettingsSection(title: "Projects", icon: "folder") {
            ForEach(Array(store.data.projects.enumerated()), id: \.element.id) { index, p in
                if index > 0 { RowDivider() }
                EditableRow(
                    item: store.binding(\.projects, p),
                    canMoveUp: index > 0,
                    canMoveDown: index < store.data.projects.count - 1,
                    canDelete: true,
                    onMove: { store.move(\.projects, id: p.id, by: $0) },
                    onDelete: { store.deleteProject(p.id) },
                    extra: { EmptyView() }
                )
            }
            if !store.data.projects.isEmpty { RowDivider() }
            AddRowButton(title: "Add project") { store.addProject(name: "New project") }
        }
    }

    private var defaults: some View {
        SettingsSection(title: "New tasks", icon: "plus.square") {
            SettingRow(title: "Default priority") {
                Picker("", selection: Binding(
                    get: { store.defaultPriorityID },
                    set: { store.data.settings.defaultPriorityID = $0 }
                )) {
                    ForEach(store.data.priorities) { Text($0.name.isEmpty ? "Untitled" : $0.name).tag($0.id) }
                }
                .labelsHidden()
                .frame(width: 180)
            }
            RowDivider()
            SettingRow(title: "Default status") {
                Picker("", selection: Binding(
                    get: { store.defaultStatusID },
                    set: { store.data.settings.defaultStatusID = $0 }
                )) {
                    ForEach(store.data.statuses.filter { !$0.isClosed }) { Text($0.name.isEmpty ? "Untitled" : $0.name).tag($0.id) }
                }
                .labelsHidden()
                .frame(width: 180)
            }
            RowDivider()
            SettingRow(title: "Checking the circle sets", caption: "The status a task gets when you tick it.") {
                Picker("", selection: Binding(
                    get: { store.doneStatusID },
                    set: { store.data.settings.doneStatusID = $0 }
                )) {
                    ForEach(store.data.statuses.filter { $0.isClosed }) { Text($0.name.isEmpty ? "Untitled" : $0.name).tag($0.id) }
                }
                .labelsHidden()
                .frame(width: 180)
            }
        }
    }

    private var dataSection: some View {
        SettingsSection(title: "Data", icon: "externaldrive") {
            SettingRow(title: "Data file", caption: "Everything is stored locally in one JSON file.") {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                }
            }
            RowDivider()
            SettingRow(title: "Clear completed tasks", caption: "Permanently removes every completed task.") {
                Button("Clear…", role: .destructive) { confirmClear = true }
                    .confirmationDialog("Delete all completed tasks?", isPresented: $confirmClear) {
                        Button("Delete", role: .destructive) { store.clearCompleted() }
                    } message: {
                        Text("This can’t be undone.")
                    }
            }
        }
    }

    private func closedBinding(_ s: TaskStatus) -> Binding<Bool> {
        Binding(
            get: { store.status(s.id)?.isClosed ?? s.isClosed },
            set: { value in
                if let i = store.data.statuses.firstIndex(where: { $0.id == s.id }) {
                    store.data.statuses[i].isClosed = value
                    store.normalize()
                }
            }
        )
    }
}

// MARK: - Building blocks

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    var caption: String? = nil
    @ViewBuilder var content: () -> Content

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                    Text(title)
                        .font(.jakarta(15, .semibold))
                        .foregroundStyle(palette.primaryText)
                }
                if let caption {
                    Text(caption)
                        .font(.jakarta(12))
                        .foregroundStyle(palette.secondaryText)
                }
            }
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.inset))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(palette.separator))
        }
    }
}

struct SettingRow<Control: View>: View {
    let title: String
    var caption: String? = nil
    @ViewBuilder var control: () -> Control

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.jakarta(13))
                    .foregroundStyle(palette.primaryText)
                if let caption {
                    Text(caption)
                        .font(.jakarta(11))
                        .foregroundStyle(palette.secondaryText)
                }
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct RowDivider: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Rectangle().fill(palette.separator).frame(height: 1).padding(.leading, 14)
    }
}

struct EditableRow<Item: Colorable, Extra: View>: View {
    @Binding var item: Item
    let canMoveUp: Bool
    let canMoveDown: Bool
    let canDelete: Bool
    let onMove: (Int) -> Void
    let onDelete: () -> Void
    @ViewBuilder var extra: () -> Extra

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            ColorSwatchPicker(hex: $item.colorHex)
            TextField("Name", text: $item.name)
                .textFieldStyle(.plain)
                .font(.jakarta(13))
                .foregroundStyle(palette.primaryText)
            extra()
                .padding(.trailing, 6)
            IconButton(systemName: "chevron.up", help: "Move up", disabled: !canMoveUp) { onMove(-1) }
            IconButton(systemName: "chevron.down", help: "Move down", disabled: !canMoveDown) { onMove(1) }
            IconButton(systemName: "trash", help: "Delete", destructive: true, disabled: !canDelete) { onDelete() }
        }
        .padding(.leading, 9)
        .padding(.trailing, 8)
        .frame(height: 42)
    }
}

struct AddRowButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.palette) private var palette
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24)
                Text(title).font(.jakarta(13))
                Spacer()
            }
            .foregroundStyle(hover ? palette.primaryText : palette.secondaryText)
            .padding(.horizontal, 9)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
