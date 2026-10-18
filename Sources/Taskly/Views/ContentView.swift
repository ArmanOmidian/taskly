import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var ui: UIState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette.forScheme(colorScheme)

        HStack(spacing: 12) {
            Sidebar()
                .frame(width: 232)
                .frame(maxHeight: .infinity)
                .background(panel(palette, radius: 16))

            Group {
                if ui.selection == .settings {
                    SettingsView()
                } else {
                    TaskListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(panel(palette, radius: 18))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 36)   // grey strip at the top that holds the window's close/minimize/zoom buttons
        .background(palette.window)
        .ignoresSafeArea()
        .environment(\.palette, palette)
        .font(.jakarta(13))
        .frame(minWidth: 1000, minHeight: 560)
        .onAppear {
            applyTheme(store.data.settings.theme)
            NotificationManager.shared.setup(store: store)
        }
        .onChange(of: store.data.settings.theme) { _, theme in applyTheme(theme) }
    }

    private func panel(_ palette: Palette, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(palette.panel)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.04), radius: 10, y: 2)
    }

    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
