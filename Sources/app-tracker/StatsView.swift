import SwiftUI
import AppKit
import Charts

/// Тема оформления окна статистики.
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct StatsView: View {
    @State private var date = Date()
    @State private var groups: [AppGroup] = []
    @AppStorage("appTheme") private var theme: AppTheme = .system

    private var totalSeconds: Int { groups.reduce(0) { $0 + $1.totalSeconds } }
    private var maxGroupSeconds: Int { groups.first?.totalSeconds ?? 1 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(groups) { group in
                            GroupCard(group: group,
                                      fraction: groupFraction(group.totalSeconds),
                                      date: date)
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 480)
        .preferredColorScheme(theme.colorScheme)
        .onAppear(perform: reload)
        .onChange(of: date) { _ in reload() }
    }

    private var header: some View {
        HStack {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.field)
                .labelsHidden()
            Button(action: reload) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
            Spacer()
            Text("Total: \(formatDuration(totalSeconds))")
                .font(.headline)
                .foregroundStyle(.secondary)
            themePicker
        }
        .padding(12)
    }

    private var themePicker: some View {
        Menu {
            Picker("Theme", selection: $theme) {
                ForEach(AppTheme.allCases) { t in
                    Label(t.title, systemImage: t.symbol).tag(t)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Image(systemName: theme.symbol)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Appearance")
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No data for this day")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func groupFraction(_ seconds: Int) -> Double {
        maxGroupSeconds > 0 ? Double(seconds) / Double(maxGroupSeconds) : 0
    }

    private func reload() {
        // Форсируем запись текущих секунд на диск, чтобы показать самые свежие данные.
        Tracker.shared.flush()
        groups = Storage.groups(for: date)
    }
}

/// Карточка одного приложения с его окнами. Свёрнута по умолчанию.
private struct GroupCard: View {
    let group: AppGroup
    /// Доля времени приложения относительно самого активного приложения (для полоски).
    let fraction: Double
    /// Дата, относительно которой строится недельная динамика.
    let date: Date

    @State private var expanded = false
    @State private var showTrend = false
    @State private var showInfo = false

    private var maxItemSeconds: Int { group.items.first?.seconds ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                header
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                    TitleRow(item: item, fraction: itemFraction(item.seconds))
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
            Image(nsImage: NSWorkspace.shared.icon(forFile: group.appPath))
                .resizable()
                .frame(width: 20, height: 20)
            Text(group.appName)
                .font(.body.weight(.semibold))
            Spacer(minLength: 8)
            Text(formatDuration(group.totalSeconds))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            infoButton
            trendButton
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(alignment: .leading) { ProgressBar(fraction: fraction) }
        .contentShape(Rectangle())
    }

    private var trendButton: some View {
        Button {
            showTrend.toggle()
        } label: {
            Image(systemName: "chart.bar.xaxis")
                .font(.subheadline)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("Weekly trend")
        .popover(isPresented: $showTrend, arrowEdge: .bottom) {
            WeeklyTrendView(appName: group.appName,
                            data: Storage.weeklyTotals(forApp: group.appPath, endingAt: date))
        }
    }

    private var infoButton: some View {
        Button {
            showInfo.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.subheadline)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("App info")
        .popover(isPresented: $showInfo, arrowEdge: .bottom) {
            AppInfoView(group: group)
        }
    }

    private func itemFraction(_ seconds: Int) -> Double {
        maxItemSeconds > 0 ? Double(seconds) / Double(maxItemSeconds) : 0
    }
}

/// Одна строка «тайтл окна … длительность» с фоновым баром прогресса.
private struct TitleRow: View {
    let item: Entry
    let fraction: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(item.title.isEmpty ? "(no title)" : item.title)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(item.title.isEmpty ? .secondary : .primary)
            Spacer(minLength: 8)
            Text(formatDuration(item.seconds))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(alignment: .leading) { ProgressBar(fraction: fraction) }
    }
}

/// Недельная динамика по приложению: столбчатый график за 7 дней.
private struct WeeklyTrendView: View {
    let appName: String
    let data: [DayTotal]

    private var totalSeconds: Int { data.reduce(0) { $0 + $1.seconds } }

    private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appName)
                .font(.headline)
                .lineLimit(1)
            Text("Last 7 days · \(formatDuration(totalSeconds))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(data) { day in
                BarMark(
                    x: .value("Day", Self.weekday.string(from: day.date)),
                    y: .value("Minutes", Double(day.seconds) / 60.0)
                )
                .foregroundStyle(Color.accentColor)
                .cornerRadius(3)
            }
            .chartXScale(domain: data.map { Self.weekday.string(from: $0.date) })
            .chartYAxisLabel("min")
            .frame(width: 300, height: 160)
        }
        .padding(14)
    }
}

/// Подробная информация о приложении: имя, путь, статистика за день.
private struct AppInfoView: View {
    let group: AppGroup

    private var bundle: Bundle? { Bundle(path: group.appPath) }
    private var bundleID: String { bundle?.bundleIdentifier ?? "—" }
    private var version: String {
        let short = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = bundle?.infoDictionary?["CFBundleVersion"] as? String
        switch (short, build) {
        case let (s?, b?): return "\(s) (\(b))"
        case let (s?, nil): return s
        case let (nil, b?): return b
        default: return "—"
        }
    }
    private var windowCount: Int { group.items.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: group.appPath))
                    .resizable()
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.appName)
                        .font(.headline)
                    Text(bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                infoRow("Time today", formatDuration(group.totalSeconds))
                infoRow("Tracked windows", "\(windowCount)")
                infoRow("Version", version)
                infoRow("Path", group.appPath, mono: true)
            }

            HStack {
                Spacer()
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: group.appPath)])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
            }
        }
        .padding(16)
        .frame(width: 340, alignment: .leading)
    }

    private func infoRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(mono ? .callout.monospaced() : .callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Фоновая полоска прогресса. Непрозрачность подобрана под тему для контраста.
private struct ProgressBar: View {
    let fraction: Double
    @Environment(\.colorScheme) private var colorScheme

    private var fillOpacity: Double { colorScheme == .dark ? 0.32 : 0.22 }

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(fillOpacity))
                .frame(width: max(0, geo.size.width * fraction))
        }
    }
}
