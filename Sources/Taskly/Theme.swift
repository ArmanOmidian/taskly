import SwiftUI
import AppKit

// MARK: - Palette (light / dark)

struct Palette: Sendable {
    var window: Color
    var panel: Color
    var inset: Color
    var hover: Color
    var pill: Color
    var separator: Color
    var primaryText: Color
    var secondaryText: Color
    var tertiaryText: Color
    var danger: Color

    static let light = Palette(
        window: Color(hex: "#EDEDEF"),
        panel: Color(hex: "#FFFFFF"),
        inset: Color(hex: "#F6F6F7"),
        hover: Color(hex: "#F5F5F7"),
        pill: Color(hex: "#EBEBEE"),
        separator: Color(hex: "#ECECEE"),
        primaryText: Color(hex: "#111113"),
        secondaryText: Color(hex: "#77777D"),
        tertiaryText: Color(hex: "#B2B2B8"),
        danger: Color(hex: "#FF453A")
    )

    static let dark = Palette(
        window: Color(hex: "#141416"),
        panel: Color(hex: "#1F1F22"),
        inset: Color(hex: "#26262A"),
        hover: Color(hex: "#27272B"),
        pill: Color(hex: "#323237"),
        separator: Color(hex: "#2E2E33"),
        primaryText: Color(hex: "#F2F2F4"),
        secondaryText: Color(hex: "#9A9AA1"),
        tertiaryText: Color(hex: "#5F5F66"),
        danger: Color(hex: "#FF5A50")
    )

    static func forScheme(_ scheme: ColorScheme) -> Palette { scheme == .dark ? .dark : .light }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .light
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Color presets for priorities / statuses / projects

enum ColorPresets {
    static let all = [
        "#FF453A", "#FF9F0A", "#FFD60A", "#30D158", "#2FB9C9",
        "#2F6BFF", "#7C5CFF", "#FF4FA3", "#8E8E93", "#3A3A3C",
    ]

    static func next(after used: [String]) -> String {
        let usedSet = Set(used.map { $0.uppercased() })
        return all.first { !usedSet.contains($0.uppercased()) } ?? all[used.count % all.count]
    }
}

// MARK: - Hex helpers

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }

    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.gray
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Due date formatting

enum DueFormat {
    static func dayOffset(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
    }

    static func dayLabel(_ date: Date, relative: Bool) -> String {
        guard relative else { return date.formatted(.dateTime.month(.abbreviated).day()) }
        let n = dayOffset(date)
        switch n {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case let n where n > 1: return "\(n) Days"
        default: return "\(-n) days ago"
        }
    }

    static func label(_ date: Date, hasTime: Bool, relative: Bool) -> String {
        let day = dayLabel(date, relative: relative)
        guard hasTime else { return day }
        return day + ", " + date.formatted(date: .omitted, time: .shortened)
    }

    static func isOverdue(_ date: Date, hasTime: Bool) -> Bool {
        hasTime ? date < Date() : dayOffset(date) < 0
    }

    /// Keeps the calendar day of `day` and the hour/minute of `time`.
    static func combine(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let t = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(bySettingHour: t.hour ?? 9, minute: t.minute ?? 0, second: 0, of: day) ?? day
    }

    /// The next full hour from now, on the given day (used when turning time on).
    static func defaultTime(on day: Date) -> Date {
        let cal = Calendar.current
        let hour = min(cal.component(.hour, from: Date()) + 1, 23)
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }
}

// MARK: - Column widths (shared by header + rows)

enum Col {
    static let check: CGFloat = 30
    static let due: CGFloat = 158
    static let priority: CGFloat = 108
    static let project: CGFloat = 124
    static let status: CGFloat = 124
    static let actions: CGFloat = 72
}
