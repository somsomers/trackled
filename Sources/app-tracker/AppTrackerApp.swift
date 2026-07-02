import SwiftUI
import AppKit

/// Настройка при запуске: прячем Dock-иконку и запускаем трекинг.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let tracker = Tracker.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // только menu-bar, без Dock
        tracker.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tracker.flush()
    }
}

@main
struct TrackledApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var statsWindow = StatsWindowController()
    @StateObject private var settingsWindow = SettingsWindowController()

    var body: some Scene {
        MenuBarExtra("Trackled", systemImage: "clock") {
            Button("Statistics…") { statsWindow.show() }
            Button("Settings…") { settingsWindow.show() }
                .keyboardShortcut(",")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Ленивое ручное управление окном статистики (без авто-открытия при запуске).
final class StatsWindowController: NSObject, ObservableObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: StatsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Statistics"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 460, height: 580))
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Сбрасываем ссылку, чтобы при следующем открытии данные подгрузились заново.
        window = nil
    }
}

/// Ленивое управление окном настроек.
final class SettingsWindowController: NSObject, ObservableObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
