import WidgetKit
import SwiftUI
import ActivityKit

enum WidgetShared {
    static let appGroupID = "group.br.com.antonio.Antikaos"
    static let widgetKind = "AntikaosChaosWidget"
    static let chaosValueKey = "widget.chaosValue"
    static let deadlinesKey = "widget.deadlines"
    static let hasPremiumAccessKey = "widget.hasPremiumAccess"
}

private enum WidgetFont {
    static func schoolbell(size: CGFloat) -> Font {
        .custom("Schoolbell", size: size)
    }

    static func schoolbellOrRounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Schoolbell", size: size, relativeTo: .body)
    }
}

struct AntikaosWidgetEntry: TimelineEntry {
    let date: Date
    let chaosValue: Int
    let deadlines: [WidgetDeadlineEntry]
    let hasPremiumAccess: Bool
}

struct WidgetDeadlineEntry: Codable, Identifiable {
    let id: UUID
    let title: String
    let deadlineDate: Date
    let difficulty: Int
    let completedSessions: Int
    let totalSessions: Int
}

struct ChaosActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let chaosValue: Int
        let levelTitle: String
        let updatedAt: Date
    }

    let title: String
}

struct AntikaosWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AntikaosWidgetEntry {
        AntikaosWidgetEntry(
            date: .now,
            chaosValue: 34,
            deadlines: [
                .init(id: UUID(), title: "Prova de Cálculo", deadlineDate: .now.addingTimeInterval(86400), difficulty: 74, completedSessions: 1, totalSessions: 3),
                .init(id: UUID(), title: "Trabalho de Design", deadlineDate: .now.addingTimeInterval(172800), difficulty: 48, completedSessions: 2, totalSessions: 4),
                .init(id: UUID(), title: "Estudar SwiftUI", deadlineDate: .now.addingTimeInterval(345600), difficulty: 26, completedSessions: 0, totalSessions: 2)
            ],
            hasPremiumAccess: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AntikaosWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AntikaosWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry() -> AntikaosWidgetEntry {
        let defaults = UserDefaults(suiteName: WidgetShared.appGroupID)
        let value = defaults?.integer(forKey: WidgetShared.chaosValueKey) ?? 0
        let hasPremiumAccess = defaults?.bool(forKey: WidgetShared.hasPremiumAccessKey) ?? false
        let deadlines: [WidgetDeadlineEntry]
        if let data = defaults?.data(forKey: WidgetShared.deadlinesKey),
           let decoded = try? JSONDecoder().decode([WidgetDeadlineEntry].self, from: data) {
            deadlines = decoded
        } else {
            deadlines = []
        }

        return AntikaosWidgetEntry(date: .now, chaosValue: value, deadlines: deadlines, hasPremiumAccess: hasPremiumAccess)
    }
}

private enum WidgetChaosLevel {
    case controlled
    case moderate
    case high
    case critical

    init(value: Int) {
        switch value {
        case 0...30:
            self = .controlled
        case 31...60:
            self = .moderate
        case 61...80:
            self = .high
        default:
            self = .critical
        }
    }

    var title: String {
        switch self {
        case .controlled:
            return "Sobrecarga controlada"
        case .moderate:
            return "Sobrecarga moderada"
        case .high:
            return "Sobrecarga alta"
        case .critical:
            return "Sobrecarga crítica"
        }
    }

    var tint: Color {
        switch self {
        case .controlled:
            return Color(red: 0.45, green: 0.61, blue: 0.48)
        case .moderate:
            return Color(red: 216 / 255, green: 113 / 255, blue: 66 / 255)
        case .high:
            return Color(red: 0.82, green: 0.54, blue: 0.22)
        case .critical:
            return Color(red: 0.72, green: 0.34, blue: 0.27)
        }
    }
}

struct AntikaosChaosWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: AntikaosWidgetProvider.Entry

    var body: some View {
        if !entry.hasPremiumAccess {
            lockedWidget
        } else {
            switch family {
            case .systemMedium:
                mediumWidget
            default:
                smallWidget
            }
        }
    }

    private var lockedWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Antikaos Premium")
                .font(WidgetFont.schoolbell(size: 22))
                .foregroundStyle(Color.black.opacity(0.88))

            Text("Desbloqueie widgets, histórico ilimitado e deadlines sem limite no app.")
                .font(WidgetFont.schoolbell(size: 14))
                .foregroundStyle(Color.black.opacity(0.62))
                .multilineTextAlignment(.leading)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Abra o app para desbloquear")
                    .font(WidgetFont.schoolbell(size: 14))
            }
            .foregroundStyle(Color(red: 216 / 255, green: 113 / 255, blue: 66 / 255))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .widgetURL(URL(string: "antikaos://premium/widgets"))
        .containerBackground(for: .widget) {
            Color(red: 244 / 255, green: 237 / 255, blue: 232 / 255)
        }
    }

    private var smallWidget: some View {
        let level = WidgetChaosLevel(value: entry.chaosValue)

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(red: 234 / 255, green: 225 / 255, blue: 218 / 255), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: CGFloat(Double(entry.chaosValue) / 100))
                    .stroke(level.tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 3) {
                    Text("\(entry.chaosValue)")
                        .font(WidgetFont.schoolbell(size: 34))
                        .foregroundStyle(Color.black.opacity(0.88))

                    Text("/100")
                        .font(WidgetFont.schoolbell(size: 16))
                        .foregroundStyle(Color.black.opacity(0.55))
                }
            }
            .frame(width: 112, height: 112)

            Text(level.title)
                .font(WidgetFont.schoolbell(size: 15))
                .foregroundStyle(level.tint)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .containerBackground(for: .widget) {
            Color(red: 244 / 255, green: 237 / 255, blue: 232 / 255)
        }
    }

    private var mediumWidget: some View {
        GeometryReader { proxy in
            let visibleDeadlines = Array(entry.deadlines.prefix(3))
            let deadlineCount = visibleDeadlines.count
            let compact = proxy.size.width < 340 || deadlineCount >= 3
            let titleSize: CGFloat = compact ? 20 : 22
            let summarySize: CGFloat = compact ? 12 : 13
            let circleSize: CGFloat = compact ? 62 : 70
            let rowSpacing: CGFloat = deadlineCount <= 1 ? 10 : 8

            VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Próximas deadlines")
                            .font(WidgetFont.schoolbell(size: titleSize))
                            .foregroundStyle(Color.black.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(statusSummary(for: deadlineCount))
                            .font(WidgetFont.schoolbell(size: summarySize))
                            .foregroundStyle(Color.black.opacity(0.52))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 10)

                    ZStack {
                        Circle()
                            .stroke(Color(red: 234 / 255, green: 225 / 255, blue: 218 / 255), lineWidth: compact ? 8 : 10)

                        Circle()
                            .trim(from: 0, to: CGFloat(Double(entry.chaosValue) / 100))
                            .stroke(WidgetChaosLevel(value: entry.chaosValue).tint, style: StrokeStyle(lineWidth: compact ? 8 : 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))

                        Text("\(entry.chaosValue)")
                            .font(WidgetFont.schoolbell(size: compact ? 20 : 22))
                            .foregroundStyle(Color.black.opacity(0.88))
                            .minimumScaleFactor(0.8)
                    }
                    .frame(width: circleSize, height: circleSize)
                }

                if visibleDeadlines.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nenhuma deadline ativa")
                            .font(WidgetFont.schoolbell(size: compact ? 16 : 18))
                            .foregroundStyle(Color.black.opacity(0.84))

                        Text("Sua sobrecarga está sob controle por enquanto.")
                            .font(WidgetFont.schoolbell(size: compact ? 12 : 13))
                            .foregroundStyle(Color.black.opacity(0.54))
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(spacing: rowSpacing) {
                        ForEach(visibleDeadlines) { deadline in
                            deadlineRow(deadline, compact: compact, multiLineTitle: deadlineCount == 1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(compact ? 14 : 16)
        }
        .containerBackground(for: .widget) {
            Color(red: 244 / 255, green: 237 / 255, blue: 232 / 255)
        }
    }

    private func statusSummary(for count: Int) -> String {
        if count == 0 {
            return "Sem prazos por agora"
        } else if count == 1 {
            return "1 deadline próxima"
        } else {
            return "\(count) deadlines próximas"
        }
    }

    @ViewBuilder
    private func deadlineRow(_ deadline: WidgetDeadlineEntry, compact: Bool, multiLineTitle: Bool) -> some View {
        let tint = tint(for: deadline.difficulty)

        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: compact ? 9 : 10, height: compact ? 9 : 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(deadline.title)
                    .font(WidgetFont.schoolbell(size: compact ? 15 : 17))
                    .foregroundStyle(Color.black.opacity(0.86))
                    .lineLimit(multiLineTitle ? 2 : 1)
                    .minimumScaleFactor(0.8)

                Text(deadlineMeta(for: deadline))
                    .font(WidgetFont.schoolbell(size: compact ? 11 : 12))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            Text(shortDate(for: deadline.deadlineDate))
                .font(WidgetFont.schoolbell(size: compact ? 12 : 14))
                .foregroundStyle(Color.black.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private func deadlineMeta(for deadline: WidgetDeadlineEntry) -> String {
        let sessions = "\(deadline.completedSessions)/\(max(deadline.totalSessions, 1)) sessões"
        let due = relativeDueText(for: deadline.deadlineDate)
        return "\(sessions) • \(due)"
    }

    private func shortDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }

    private func relativeDueText(for date: Date) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0

        switch days {
        case ..<0:
            return "atrasada"
        case 0:
            return "hoje"
        case 1:
            return "amanhã"
        default:
            return "em \(days)d"
        }
    }

    private func tint(for difficulty: Int) -> Color {
        WidgetChaosLevel(value: difficulty).tint
    }
}

struct AntikaosChaosWidget: Widget {
    let kind: String = WidgetShared.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AntikaosWidgetProvider()) { entry in
            AntikaosChaosWidgetView(entry: entry)
        }
        .configurationDisplayName("Sobrecarga do usuário")
        .description("Mostra a sobrecarga atual e as próximas deadlines do usuário.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AntikaosChaosLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChaosActivityAttributes.self) { context in
            ChaosLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 244 / 255, green: 237 / 255, blue: 232 / 255))
                .activitySystemActionForegroundColor(WidgetChaosLevel(value: context.state.chaosValue).tint)
        } dynamicIsland: { context in
            let state = context.state
            let level = WidgetChaosLevel(value: state.chaosValue)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        ChaosLiveActivityGauge(value: state.chaosValue, size: 46, lineWidth: 5)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sobrecarga")
                                .font(WidgetFont.schoolbell(size: 18))
                                .foregroundStyle(Color.white.opacity(0.86))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Text(state.levelTitle)
                                .font(WidgetFont.schoolbell(size: 17))
                                .foregroundStyle(level.tint)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(state.chaosValue)")
                            .font(WidgetFont.schoolbell(size: 28))
                            .foregroundStyle(level.tint)
                            .lineLimit(1)

                        Text("/100")
                            .font(WidgetFont.schoolbell(size: 13))
                            .foregroundStyle(Color.white.opacity(0.62))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        ProgressView(value: min(max(Double(state.chaosValue), 0), 100), total: 100)
                            .tint(level.tint)

                        HStack {
                            Text("Atualizado \(relativeUpdateText(for: state.updatedAt))")
                                .font(WidgetFont.schoolbell(size: 13))
                                .foregroundStyle(Color.white.opacity(0.68))

                            Spacer()

                            Text("\(state.chaosValue)/100")
                                .font(WidgetFont.schoolbell(size: 14))
                                .foregroundStyle(level.tint)
                        }
                    }
                }
            } compactLeading: {
                Text("Sobrecarga")
                    .font(WidgetFont.schoolbell(size: 13))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } compactTrailing: {
                ChaosLiveActivityGauge(value: state.chaosValue, size: 28, lineWidth: 3)
            } minimal: {
                ChaosLiveActivityGauge(value: state.chaosValue, size: 24, lineWidth: 3)
            }
            .keylineTint(level.tint)
        }
    }

    private func relativeUpdateText(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct ChaosLiveActivityLockScreenView: View {
    let state: ChaosActivityAttributes.ContentState

    var body: some View {
        let level = WidgetChaosLevel(value: state.chaosValue)

        HStack(spacing: 14) {
            ChaosLiveActivityGauge(value: state.chaosValue, size: 62, lineWidth: 7)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sobrecarga do usuário")
                    .font(WidgetFont.schoolbell(size: 19))
                    .foregroundStyle(Color.black.opacity(0.88))

                Text(state.levelTitle)
                    .font(WidgetFont.schoolbell(size: 16))
                    .foregroundStyle(level.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            Text("\(state.chaosValue)/100")
                .font(WidgetFont.schoolbell(size: 20))
                .foregroundStyle(Color.black.opacity(0.82))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct ChaosLiveActivityGauge: View {
    let value: Int
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        let level = WidgetChaosLevel(value: value)
        let progress = min(max(Double(value) / 100, 0), 1)

        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(level.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(value)")
                .font(WidgetFont.schoolbell(size: max(size * 0.34, 12)))
                .foregroundStyle(level.tint)
                .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
    }
}

@main
struct AntikaosWidgetBundle: WidgetBundle {
    var body: some Widget {
        AntikaosChaosWidget()
        AntikaosChaosLiveActivity()
    }
}
