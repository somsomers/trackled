import Foundation
import AppKit
import ApplicationServices

/// Движок трекинга: раз в секунду фиксирует активное окно и копит секунды за текущий день.
final class Tracker {
    /// Общий экземпляр — чтобы UI мог форсировать флаш перед чтением статистики.
    static let shared = Tracker()

    /// Как часто опрашиваем активное окно (в секундах). Настраивается в UserDefaults.
    private var sampleInterval: TimeInterval { AppSettings.sampleInterval }
    /// Через сколько секунд бездействия прекращаем отслеживание. Настраивается.
    private var idleThreshold: TimeInterval { AppSettings.idleThreshold }
    /// Как часто сбрасываем накопленную статистику на диск.
    private let flushInterval: TimeInterval = 10.0

    private var totals: [Key: Int] = [:]
    private var currentDay: String
    private var secondsSinceFlush: TimeInterval = 0
    private var timer: Timer?

    init() {
        currentDay = Storage.dayString(Date())
        // Дочитываем то, что уже накоплено за сегодня (если приложение перезапускали).
        for e in Storage.loadEntries(for: Date()) {
            totals[Key(appPath: e.appPath, title: e.title), default: 0] += e.seconds
        }
    }

    func start() {
        ensureAccessibility()
        scheduleTimer()
    }

    /// Пересоздать таймер с текущим интервалом опроса (после изменения настроек).
    func restart() {
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: sampleInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func flush() {
        Storage.save(totals, for: Date())
    }

    // MARK: - Один тик опроса

    private func tick() {
        // Смена суток: сохраняем прошлый день и начинаем новый.
        let today = Storage.dayString(Date())
        if today != currentDay {
            flush()
            totals.removeAll()
            currentDay = today
        }

        // Пропускаем время бездействия.
        if secondsSinceLastInput() >= idleThreshold { return }

        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let appPath = app.bundleURL?.path ?? app.executableURL?.path ?? (app.localizedName ?? "unknown")
        let title = focusedWindowTitle(pid: app.processIdentifier) ?? ""

        totals[Key(appPath: appPath, title: title), default: 0] += Int(sampleInterval)

        secondsSinceFlush += sampleInterval
        if secondsSinceFlush >= flushInterval {
            flush()
            secondsSinceFlush = 0
        }
    }

    // MARK: - Опрос системы

    /// Тайтл сфокусированного окна процесса через Accessibility API.
    private func focusedWindowTitle(pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef else { return nil }
        let window = windowRef as! AXUIElement
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success else { return nil }
        return titleRef as? String
    }

    /// Секунды с момента последнего ввода (мышь/клавиатура).
    private func secondsSinceLastInput() -> TimeInterval {
        let anyEvent = CGEventType(rawValue: ~0)!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
    }

    /// Проверка прав Accessibility (без них не читаются тайтлы окон).
    private func ensureAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if !trusted {
            NSLog("Trackled: no Accessibility permission — window titles won't be read. "
                + "Grant access in System Settings → Privacy & Security → Accessibility.")
        }
    }
}
