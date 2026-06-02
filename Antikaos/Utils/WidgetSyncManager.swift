import Foundation
import WidgetKit

enum WidgetShared {
    static let appGroupID = "group.br.com.antonio.Antikaos"
    static let widgetKind = "AntikaosChaosWidget"
    static let chaosValueKey = "widget.chaosValue"
    static let chaosUpdatedAtKey = "widget.chaosUpdatedAt"
    static let deadlinesKey = "widget.deadlines"
    static let hasPremiumAccessKey = "widget.hasPremiumAccess"
}

struct WidgetDeadlinePayload: Codable {
    let id: UUID
    let title: String
    let deadlineDate: Date
    let difficulty: Int
    let completedSessions: Int
    let totalSessions: Int
}

enum WidgetSyncManager {
    static func syncChaos(from tasks: [TaskItem]) {
        let chaosValue = ChaosCalculator.overallChaos(for: tasks)
        let upcomingDeadlines = ChaosCalculator.activeTasksForOverload(from: tasks)
            .sorted { lhs, rhs in
                if lhs.deadlineDate != rhs.deadlineDate {
                    return lhs.deadlineDate < rhs.deadlineDate
                }

                return lhs.updatedAt > rhs.updatedAt
            }
            .prefix(3)
            .map {
                WidgetDeadlinePayload(
                    id: $0.id,
                    title: $0.title,
                    deadlineDate: $0.deadlineDate,
                    difficulty: $0.perceivedDifficulty,
                    completedSessions: $0.completedSessions,
                    totalSessions: max($0.tasksQuantity, 1)
                )
            }

        let defaults = UserDefaults(suiteName: WidgetShared.appGroupID)
        defaults?.set(chaosValue, forKey: WidgetShared.chaosValueKey)
        defaults?.set(Date(), forKey: WidgetShared.chaosUpdatedAtKey)
        if let encodedDeadlines = try? JSONEncoder().encode(upcomingDeadlines) {
            defaults?.set(encodedDeadlines, forKey: WidgetShared.deadlinesKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.widgetKind)
    }
}
