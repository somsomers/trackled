import Foundation

// MARK: - Модель данных

/// Ключ агрегации: путь к приложению + тайтл окна.
struct Key: Hashable, Codable {
    let appPath: String
    let title: String
}

/// Одна запись статистики (единица хранения в JSON).
struct Entry: Codable {
    let appPath: String
    let title: String
    let seconds: Int
}

/// Группа для отображения: одно приложение и его окна.
struct AppGroup: Identifiable {
    let appPath: String
    let appName: String
    let totalSeconds: Int
    let items: [Entry]      // тайтлы, отсортированы по времени убыв.

    var id: String { appPath }
}

/// Суммарное время за один день (для графика динамики).
struct DayTotal: Identifiable {
    let date: Date
    let seconds: Int
    var id: Date { date }
}

// MARK: - Хранилище по датам

enum Storage {
    /// ~/Library/Application Support/Trackled/
    static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Trackled", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            // Переносим данные из старого каталога AppTracker, если он остался.
            let legacy = base.appendingPathComponent("AppTracker", isDirectory: true)
            if FileManager.default.fileExists(atPath: legacy.path) {
                try? FileManager.default.moveItem(at: legacy, to: dir)
            }
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Форматтер даты для имени файла — фиксированные локаль/таймзона (локальный день).
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayString(_ date: Date) -> String { dayFormatter.string(from: date) }

    /// Файл со статистикой за конкретный день.
    static func fileURL(for date: Date) -> URL {
        directory().appendingPathComponent("\(dayString(date)).json")
    }

    /// Прочитать записи за день (пусто, если файла нет).
    static func loadEntries(for date: Date) -> [Entry] {
        guard let data = try? Data(contentsOf: fileURL(for: date)),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }

    /// Сохранить накопленные секунды за день (перезапись файла дня целиком).
    static func save(_ totals: [Key: Int], for date: Date) {
        let entries = totals
            .map { Entry(appPath: $0.key.appPath, title: $0.key.title, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL(for: date), options: .atomic)
    }

    /// Агрегация в группы для UI: по приложению, всё отсортировано по времени убыв.
    static func groups(for date: Date) -> [AppGroup] {
        let entries = loadEntries(for: date)
        let byApp = Dictionary(grouping: entries, by: { $0.appPath })
        return byApp.map { (appPath, items) in
            let sortedItems = items.sorted { $0.seconds > $1.seconds }
            let total = items.reduce(0) { $0 + $1.seconds }
            return AppGroup(appPath: appPath, appName: appName(from: appPath),
                            totalSeconds: total, items: sortedItems)
        }
        .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    /// Суммарные секунды за день для конкретного приложения.
    static func appSeconds(forApp appPath: String, on date: Date) -> Int {
        loadEntries(for: date)
            .filter { $0.appPath == appPath }
            .reduce(0) { $0 + $1.seconds }
    }

    /// Динамика приложения за 7 дней, заканчивая указанной датой (старые → новые).
    static func weeklyTotals(forApp appPath: String, endingAt date: Date) -> [DayTotal] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { offset -> DayTotal? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: date) else { return nil }
            return DayTotal(date: day, seconds: appSeconds(forApp: appPath, on: day))
        }
    }

    /// Человекочитаемое имя приложения из пути (без `.app`).
    static func appName(from path: String) -> String {
        let last = (path as NSString).lastPathComponent
        return last.hasSuffix(".app") ? String(last.dropLast(4)) : last
    }
}

// MARK: - Форматирование времени

/// Seconds → "1h 23m 45s" (leading zero units are dropped).
func formatDuration(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    var parts: [String] = []
    if h > 0 { parts.append("\(h)h") }
    if m > 0 { parts.append("\(m)m") }
    parts.append("\(s)s")
    return parts.joined(separator: " ")
}
