import SwiftUI
import ServiceManagement

// MARK: - Хранилище настроек

/// Настройки приложения, хранящиеся в UserDefaults.
enum AppSettings {
    static let sampleIntervalKey = "sampleInterval"
    static let idleThresholdKey = "idleThreshold"

    /// Допустимые интервалы опроса активного окна (в секундах).
    static let allowedIntervals: [Int] = [1, 2, 5, 10, 30, 60]
    /// Допустимые пороги простоя, после которых прекращается отслеживание (в секундах).
    static let allowedIdleThresholds: [Int] = [30, 60, 120, 300, 600]

    static let defaultSampleInterval = 1
    static let defaultIdleThreshold = 60

    /// Интервал опроса активного окна (в секундах), не меньше 1.
    static var sampleInterval: TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: sampleIntervalKey)
        return TimeInterval(stored > 0 ? stored : defaultSampleInterval)
    }

    /// Порог простоя (в секундах), после которого отслеживание останавливается.
    static var idleThreshold: TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: idleThresholdKey)
        return TimeInterval(stored > 0 ? stored : defaultIdleThreshold)
    }
}

// MARK: - Автозапуск при входе в систему

/// Обёртка над SMAppService для регистрации приложения как login item.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Включить/выключить автозапуск. Возвращает false при ошибке.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("Trackled: failed to \(enabled ? "enable" : "disable") login item: \(error)")
            return false
        }
    }
}

// MARK: - Окно настроек

struct SettingsView: View {
    @AppStorage(AppSettings.sampleIntervalKey) private var interval: Int = AppSettings.defaultSampleInterval
    @AppStorage(AppSettings.idleThresholdKey) private var idle: Int = AppSettings.defaultIdleThreshold
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        if !LoginItem.setEnabled(newValue) {
                            // Откатываем переключатель, если система отклонила изменение.
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
            } footer: {
                Text("Automatically start Trackled when you log in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Sampling interval", selection: $interval) {
                    ForEach(AppSettings.allowedIntervals, id: \.self) { seconds in
                        Text(intervalLabel(seconds)).tag(seconds)
                    }
                }
                .onChange(of: interval) { _ in
                    Tracker.shared.restart()
                }
            } footer: {
                Text("How often the active window is checked. Longer intervals use less CPU but are less precise.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Idle timeout", selection: $idle) {
                    ForEach(AppSettings.allowedIdleThresholds, id: \.self) { seconds in
                        Text(durationLabel(seconds)).tag(seconds)
                    }
                }
            } footer: {
                Text("Stop tracking after this much time with no keyboard or mouse activity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 340)
    }

    private func intervalLabel(_ seconds: Int) -> String {
        seconds >= 60 ? "\(seconds / 60) min" : "\(seconds) sec"
    }

    private func durationLabel(_ seconds: Int) -> String {
        seconds >= 60 ? "\(seconds / 60) min" : "\(seconds) sec"
    }
}
