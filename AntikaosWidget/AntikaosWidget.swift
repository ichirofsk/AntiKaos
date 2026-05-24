import WidgetKit
import SwiftUI

enum WidgetShared {
    static let appGroupID = "group.br.com.antonio.Antikaos"
    static let widgetKind = "AntikaosChaosWidget"
    static let chaosValueKey = "widget.chaosValue"
    static let deadlinesKey = "widget.deadlines"
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
}

struct WidgetDeadlineEntry: Codable, Identifiable {
    let id: UUID
    let title: String
    let deadlineDate: Date
    let difficulty: Int
    let completedSessions: Int
    let totalSessions: Int
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
            ]
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
        let deadlines: [WidgetDeadlineEntry]
        if let data = defaults?.data(forKey: WidgetShared.deadlinesKey),
           let decoded = try? JSONDecoder().decode([WidgetDeadlineEntry].self, from: data) {
            deadlines = decoded
        } else {
            deadlines = []
        }

        return AntikaosWidgetEntry(date: .now, chaosValue: value, deadlines: deadlines)
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
            return "Caos controlado"
        case .moderate:
            return "Caos moderado"
        case .high:
            return "Caos alto"
        case .critical:
            return "Caos crítico"
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
        switch family {
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
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
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Próximas deadlines")
                        .font(WidgetFont.schoolbell(size: 22))
                        .foregroundStyle(Color.black.opacity(0.88))

                    Text(statusSummary)
                        .font(WidgetFont.schoolbell(size: 13))
                        .foregroundStyle(Color.black.opacity(0.52))
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                ZStack {
                    Circle()
                        .stroke(Color(red: 234 / 255, green: 225 / 255, blue: 218 / 255), lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: CGFloat(Double(entry.chaosValue) / 100))
                        .stroke(WidgetChaosLevel(value: entry.chaosValue).tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Text("\(entry.chaosValue)")
                        .font(WidgetFont.schoolbell(size: 22))
                        .foregroundStyle(Color.black.opacity(0.88))
                }
                .frame(width: 70, height: 70)
            }

            if entry.deadlines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nenhuma deadline ativa")
                        .font(WidgetFont.schoolbell(size: 18))
                        .foregroundStyle(Color.black.opacity(0.84))

                    Text("Seu caos está sob controle por enquanto.")
                        .font(WidgetFont.schoolbell(size: 13))
                        .foregroundStyle(Color.black.opacity(0.54))
                }
                .frame(maxHeight: .infinity, alignment: .center)
            } else {
                VStack(spacing: 8) {
                    ForEach(entry.deadlines.prefix(3)) { deadline in
                        deadlineRow(deadline)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .containerBackground(for: .widget) {
            Color(red: 244 / 255, green: 237 / 255, blue: 232 / 255)
        }
    }

    private var statusSummary: String {
        let count = entry.deadlines.count
        if count == 0 {
            return "Sem prazos por agora"
        } else if count == 1 {
            return "1 deadline próxima"
        } else {
            return "\(count) deadlines próximas"
        }
    }

    @ViewBuilder
    private func deadlineRow(_ deadline: WidgetDeadlineEntry) -> some View {
        let tint = tint(for: deadline.difficulty)

        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(deadline.title)
                    .font(WidgetFont.schoolbell(size: 17))
                    .foregroundStyle(Color.black.opacity(0.86))
                    .lineLimit(1)

                Text(deadlineMeta(for: deadline))
                    .font(WidgetFont.schoolbell(size: 12))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(shortDate(for: deadline.deadlineDate))
                .font(WidgetFont.schoolbell(size: 14))
                .foregroundStyle(Color.black.opacity(0.58))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
        .configurationDisplayName("Caos do usuário")
        .description("Mostra o caos atual e as próximas deadlines do usuário.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AntikaosWidgetBundle: WidgetBundle {
    var body: some Widget {
        AntikaosChaosWidget()
    }
}
