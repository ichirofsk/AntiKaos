import Foundation
import ActivityKit
import WidgetKit

enum WidgetShared {
    static let appGroupID = "group.br.com.antonio.Antikaos"
    static let widgetKind = "AntikaosChaosWidget"
    static let chaosValueKey = "widget.chaosValue"
    static let chaosUpdatedAtKey = "widget.chaosUpdatedAt"
    static let deadlinesKey = "widget.deadlines"
    static let hasPremiumAccessKey = "widget.hasPremiumAccess"
    static let liveActivityEnabledKey = "liveActivity.isEnabled"
}

struct WidgetDeadlinePayload: Codable {
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

enum WidgetSyncManager {
    static func syncChaos(from tasks: [TaskItem]) {
        let chaosValue = ChaosCalculator.overallChaos(for: tasks)
        let levelTitle = AppStrings.localized(ChaosLevel(value: chaosValue).titleKey)
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

        Task {
            await syncChaosLiveActivityIfNeeded(value: chaosValue, levelTitle: levelTitle)
        }
    }

    static func setLiveActivityEnabled(_ isEnabled: Bool, tasks: [TaskItem]) {
        UserDefaults.standard.set(isEnabled, forKey: WidgetShared.liveActivityEnabledKey)

        if isEnabled {
            syncChaos(from: tasks)
        } else {
            Task {
                await endChaosLiveActivities()
            }
        }
    }

    static func reactivateLiveActivity(from tasks: [TaskItem]) {
        UserDefaults.standard.set(true, forKey: WidgetShared.liveActivityEnabledKey)
        syncChaos(from: tasks)
    }

    private static var isLiveActivityEnabled: Bool {
        guard UserDefaults.standard.object(forKey: WidgetShared.liveActivityEnabledKey) != nil else {
            return true
        }

        return UserDefaults.standard.bool(forKey: WidgetShared.liveActivityEnabledKey)
    }

    private static func syncChaosLiveActivityIfNeeded(value: Int, levelTitle: String) async {
        guard isLiveActivityEnabled else {
            await endChaosLiveActivities()
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = ChaosActivityAttributes.ContentState(
            chaosValue: value,
            levelTitle: levelTitle,
            updatedAt: .now
        )
        let content = ActivityContent(state: state, staleDate: nil)

        if let activity = Activity<ChaosActivityAttributes>.activities.first {
            await activity.update(content)
            return
        }

        do {
            _ = try Activity<ChaosActivityAttributes>.request(
                attributes: ChaosActivityAttributes(title: "Sobrecarga"),
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activities can be disabled per user/device; widgets still update normally.
        }
    }

    private static func endChaosLiveActivities() async {
        for activity in Activity<ChaosActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
