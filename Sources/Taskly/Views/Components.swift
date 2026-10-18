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
                    .font(.system(size: 13))
                    .foregroundStyle(item.id == nil ? Color.secondary : Color.primary)
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

// MARK: - Due date picker

struct DueDatePicker: View {
    let date: Date?
    let relative: Bool
    let muted: Bool
    let onChange: (Date?) -> Void

    @Environment(\.palette) private var palette
    @State private var open = false
    @State private var hover = false

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 6) {
                if let date {
                    Text(DueFormat.label(date, relative: relative))
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    quick("Today", days: 0)
                    quick("Tomorrow", days: 1)
                    quick("Next week", days: 7)
                }
                DatePicker(
                    "",
                    selection: Binding(
                        get: { date ?? Date() },
                        set: { onChange(Calendar.current.startOfDay(for: $0)) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                if date != nil {
                    Button {
                        onChange(nil)
                        open = false
                    } label: {
                        Label("Remove date", systemImage: "xmark.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.danger)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }

    private func color(for date: Date) -> Color {
        if muted { return palette.tertiaryText }
        return DueFormat.isOverdue(date) ? palette.danger : palette.primaryText
    }

    private func quick(_ title: String, days: Int) -> some View {
        Button(title) {
            let cal = Calendar.current
            let d = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: Date())) ?? Date()
            onChange(d)
            open = false
        }
        .controlSize(.small)
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
                .font(.system(size: 12))
            }
            .padding(14)
        }
    }
}
