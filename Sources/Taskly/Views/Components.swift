import SwiftUI

// MARK: - Small icon button

struct IconButton: View {
    let systemName: String
    var help: String = ""
    var destructive: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    @Environment(\.palette) private var palette
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hover && !disabled ? (destructive ? palette.danger : palette.primaryText) : palette.secondaryText)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(hover && !disabled ? palette.pill : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .onHover { hover = $0 }
        .help(help)
    }
}

// MARK: - Cell "pill" style used by the pickers in a row

private struct CellPill: ViewModifier {
    let hover: Bool
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7).fill(hover ? palette.pill : Color.clear))
            .contentShape(Rectangle())
    }
}

extension View {
    func cellPill(hover: Bool) -> some View { modifier(CellPill(hover: hover)) }
}

// MARK: - Generic option picker (priority, project, status)

struct OptionItem: Identifiable {
    let id: UUID?
    let name: String
    let color: Color?
}

struct OptionPicker: View {
    let options: [OptionItem]
    let selected: UUID?
    var placeholder: String = "—"
    var muted: Bool = false
    let onSelect: (UUID?) -> Void

    @Environment(\.palette) private var palette
    @State private var open = false
    @State private var hover = false

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 7) {
                if let current = options.first(where: { $0.id == selected }), current.id != nil {
                    if let c = current.color {
                        Circle().fill(c).frame(width: 7, height: 7).opacity(muted ? 0.45 : 1)
                    }
                    Text(current.name.isEmpty ? "Untitled" : current.name)
                        .lineLimit(1)
                        .foregroundStyle(muted ? palette.tertiaryText : palette.primaryText)
                } else {
                    Text(placeholder).foregroundStyle(palette.tertiaryText)
                }
            }
            .cellPill(hover: hover)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(options) { option in
                    OptionRow(item: option, isSelected: option.id == selected) {
                        onSelect(option.id)
                        open = false
                    }
                }
            }
            .padding(6)
            .frame(minWidth: 170)
        }
    }
}

struct OptionRow: View {
    let item: OptionItem
    let isSelected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(item.name.isEmpty ? "Untitled" : item.name)
                    .font(.jakarta(13))
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 18)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                if let c = item.color {
                    Circle().fill(c).frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.primary.opacity(0.07) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Due date + time picker

struct DueDatePicker: View {
    let date: Date?
    let hasTime: Bool
    let relative: Bool
    let muted: Bool
    /// (new date, whether it includes a time)
    let onChange: (Date?, Bool) -> Void

    @Environment(\.palette) private var palette
    @State private var open = false
    @State private var hover = false

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 6) {
                if let date {
                    Text(DueFormat.label(date, hasTime: hasTime, relative: relative))
                        .foregroundStyle(color(for: date))
                } else {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(hover ? "Set date" : "—")
                }
            }
            .foregroundStyle(palette.tertiaryText)
            .lineLimit(1)
            .cellPill(hover: hover)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    quick("Today", days: 0)
                    quick("Tomorrow", days: 1)
                    quick("Next week", days: 7)
                }

                DatePicker(
                    "",
                    selection: Binding(
                        get: { date ?? Date() },
                        set: { picked in
                            if hasTime, let date {
                                onChange(DueFormat.combine(day: picked, time: date), true)
                            } else {
                                onChange(Calendar.current.startOfDay(for: picked), false)
                            }
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Toggle("Time", isOn: Binding(
                        get: { hasTime },
                        set: { on in
                            let day = date ?? Calendar.current.startOfDay(for: Date())
                            if on {
                                onChange(DueFormat.defaultTime(on: day), true)
                            } else {
                                onChange(Calendar.current.startOfDay(for: day), false)
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    Spacer()
                    if hasTime, let date {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { date },
                                set: { onChange(DueFormat.combine(day: date, time: $0), true) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                    }
                }

                if date != nil {
                    Button {
                        onChange(nil, false)
                        open = false
                    } label: {
                        Label("Remove date", systemImage: "xmark.circle")
                            .font(.jakarta(12))
                            .foregroundStyle(palette.danger)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .frame(width: 250)
        }
    }

    private func color(for date: Date) -> Color {
        if muted { return palette.tertiaryText }
        return DueFormat.isOverdue(date, hasTime: hasTime) ? palette.danger : palette.primaryText
    }

    private func quick(_ title: String, days: Int) -> some View {
        Button(title) {
            let cal = Calendar.current
            let day = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: Date())) ?? Date()
            if hasTime, let date {
                onChange(DueFormat.combine(day: day, time: date), true)
            } else {
                onChange(day, false)
            }
        }
        .controlSize(.small)
    }
}

// MARK: - Reminder (notification) button

struct ReminderButton: View {
    let reminder: Reminder
    let hasDate: Bool
    let onSelect: (Reminder) -> Void

    @Environment(\.palette) private var palette
    @State private var open = false
    @State private var hover = false

    private var active: Bool { reminder != .none && hasDate }

    var body: some View {
        Button { open.toggle() } label: {
            Image(systemName: active ? "bell.fill" : "bell")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? palette.primaryText : (hover ? palette.primaryText : palette.secondaryText))
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(hover ? palette.pill : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(active ? "Reminder: \(reminder.label)" : "Add a reminder")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Notify me")
                    .font(.jakarta(11, .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                ForEach(Reminder.allCases) { r in
                    OptionRow(item: OptionItem(id: nil, name: r.label, color: nil), isSelected: r == reminder) {
                        onSelect(r)
                        open = false
                    }
                }
                if !hasDate {
                    Text("Set a due date to get notified.")
                        .font(.jakarta(11))
                        .foregroundStyle(palette.danger)
                        .padding(.horizontal, 9)
                        .padding(.top, 6)
                }
            }
            .padding(6)
            .frame(minWidth: 190)
        }
    }
}

// MARK: - Done circle

struct CheckCircle: View {
    let closed: Bool
    let color: Color
    let isCancel: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if closed {
                    Circle().fill(color)
                    Image(systemName: isCancel ? "xmark" : "checkmark")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.white)
                } else {
                    Circle().strokeBorder(palette.primaryText, lineWidth: 2)
                    if hover {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            }
            .frame(width: 16, height: 16)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(closed ? "Reopen task" : "Mark as done")
    }
}

// MARK: - Color swatch picker (settings)

struct ColorSwatchPicker: View {
    @Binding var hex: String
    @State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 14, height: 14)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.08)))
                .padding(5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Change color")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(22), spacing: 8), count: 5), spacing: 8) {
                    ForEach(ColorPresets.all, id: \.self) { preset in
                        Button {
                            hex = preset
                            open = false
                        } label: {
                            Circle()
                                .fill(Color(hex: preset))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle().strokeBorder(Color.primary.opacity(0.85), lineWidth: 2)
                                        .padding(-3)
                                        .opacity(preset.uppercased() == hex.uppercased() ? 1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                ColorPicker(
                    "Custom…",
                    selection: Binding(get: { Color(hex: hex) }, set: { hex = $0.hexString }),
                    supportsOpacity: false
                )
                .font(.jakarta(12))
            }
            .padding(14)
        }
    }
}
