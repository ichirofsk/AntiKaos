import WidgetKit
import SwiftUI

enum WidgetShared {
    static let appGroupID = "group.br.com.antonio.Antikaos"
    static let widgetKind = "AntikaosChaosWidget"
    static let chaosValueKey = "widget.chaosValue"
}

struct AntikaosWidgetEntry: TimelineEntry {
    let date: Date
    let chaosValue: Int
}

struct AntikaosWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AntikaosWidgetEntry {
        AntikaosWidgetEntry(date: .now, chaosValue: 34)
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
        return AntikaosWidgetEntry(date: .now, chaosValue: value)
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
    var entry: AntikaosWidgetProvider.Entry

    var body: some View {
        let level = WidgetChaosLevel(value: entry.chaosValue)

        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(red: 234 / 255, green: 225 / 255, blue: 218 / 255), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: CGFloat(Double(entry.chaosValue) / 100))
                    .stroke(level.tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 3) {
                    Text("\(entry.chaosValue)")
                        .font(.system(size: 34, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.88))

                    Text("/100")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.55))
                }
            }
            .frame(width: 112, height: 112)

            Text(level.title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
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
}

struct AntikaosChaosWidget: Widget {
    let kind: String = WidgetShared.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AntikaosWidgetProvider()) { entry in
            AntikaosChaosWidgetView(entry: entry)
        }
        .configurationDisplayName("Caos do usuário")
        .description("Mostra o caos atual do usuário.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct AntikaosWidgetBundle: WidgetBundle {
    var body: some Widget {
        AntikaosChaosWidget()
    }
}
