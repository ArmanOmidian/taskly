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
        WindowGroup("Taskly", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(ui)
                .onAppear {
                    appDelegate.store = store
                    appDelegate.ui = ui
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1140, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") { ui.newTask(store: store) }
                    .keyboardShortcut("n", modifiers: .command)
            }
            // ⌘W hides the window (app keeps running in the menu bar) instead of closing it.
            CommandGroup(replacing: .saveItem) {
                Button("Close Window") { appDelegate.hideMainWindow() }
                    .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { ui.selection = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

/// Runs Taskly as a menu bar app:
/// - Closing the window hides it and removes the Dock icon; the app keeps running (reminders keep working).
/// - Clicking the menu bar icon shows/hides the window. Right-click it for New Task / Quit.
/// - ⌘Q (or Quit in the menu bar menu) really quits.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?

    weak var store: TaskStore?
    weak var ui: UIState?
    weak var mainWindow: NSWindow?
    /// Opens a fresh window if the original one is gone (set by ContentView).
    var openWindowFallback: (() -> Void)?

    private var statusItem: NSStatusItem?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Clicking the Dock icon (or opening the app again from Finder/Spotlight) brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    // MARK: Window

    func attach(window: NSWindow) {
        guard mainWindow !== window else { return }
        mainWindow = window
        window.isReleasedWhenClosed = false
        // The red close button hides instead of closing.
        if let close = window.standardWindowButton(.closeButton) {
            close.target = self
            close.action = #selector(closeButtonClicked)
        }
    }

    @objc private func closeButtonClicked() { hideMainWindow() }

    func hideMainWindow() {
        mainWindow?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)   // removes the Dock icon
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        if let window = mainWindow {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindowFallback?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private var isWindowShowing: Bool {
        guard let w = mainWindow else { return false }
        return w.isVisible && !w.isMiniaturized && NSApp.isActive
    }

    // MARK: Menu bar icon

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Taskly")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Taskly"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showStatusMenu(from: sender)
        } else if isWindowShowing {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }

    private func showStatusMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Taskly", action: #selector(menuOpen), keyEquivalent: "")
        let newTask = NSMenuItem(title: "New Task", action: #selector(menuNewTask), keyEquivalent: "")
        let quit = NSMenuItem(title: "Quit Taskly", action: #selector(menuQuit), keyEquivalent: "q")
        for item in [open, newTask, quit] { item.target = self }
        menu.addItem(open)
        menu.addItem(newTask)
        menu.addItem(.separator())
        menu.addItem(quit)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    @objc private func menuOpen() { showMainWindow() }

    @objc private func menuNewTask() {
        showMainWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, let store = self.store, let ui = self.ui else { return }
            ui.newTask(store: store)
        }
    }

    @objc private func menuQuit() { NSApp.terminate(nil) }
}

/// Gives SwiftUI views access to their NSWindow.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window { onWindow(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window { onWindow(window) }
        }
    }
}
