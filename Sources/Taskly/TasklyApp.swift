import SwiftUI
import AppKit

@main
struct TasklyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TaskStore()
    @StateObject private var ui = UIState()

    init() {
        FontLoader.register()
    }

    var body: some Scene {
        WindowGroup("Taskly") {
            ContentView()
                .environmentObject(store)
                .environmentObject(ui)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1140, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") { ui.newTask(store: store) }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { ui.selection = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed so the app gets a Dock icon and focus when run straight from `swift run` / Xcode.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
