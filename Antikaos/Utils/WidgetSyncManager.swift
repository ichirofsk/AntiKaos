import Foundation
import WidgetKit

enum WidgetShared {
    static let appGroupID = "group.br.com.antonio.Antikaos"
    static let widgetKind = "AntikaosChaosWidget"
    static let chaosValueKey = "widget.chaosValue"
    static let chaosUpdatedAtKey = "widget.chaosUpdatedAt"
}

enum WidgetSyncManager {
    static func syncChaos(from tasks: [TaskItem]) {
        let chaosValue = ChaosCalculator.overallChaos(for: tasks)
        let defaults = UserDefaults(suiteName: WidgetShared.appGroupID)
        defaults?.set(chaosValue, forKey: WidgetShared.chaosValueKey)
        defaults?.set(Date(), forKey: WidgetShared.chaosUpdatedAtKey)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.widgetKind)
    }
}
