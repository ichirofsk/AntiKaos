import SwiftUI

enum ChaosLevel {
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

    var titleKey: String {
        switch self {
        case .controlled:
            return "chaos.controlled"
        case .moderate:
            return "chaos.moderate"
        case .high:
            return "chaos.high"
        case .critical:
            return "chaos.critical"
        }
    }

    var tint: Color {
        switch self {
        case .controlled:
            return AppTheme.supportGreen
        case .moderate:
            return AppTheme.primaryChaos
        case .high:
            return Color(red: 0.82, green: 0.54, blue: 0.22)
        case .critical:
            return AppTheme.critical
        }
    }
}
