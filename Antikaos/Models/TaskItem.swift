import Foundation
import SwiftData

enum DeadlineKind: String, Codable, CaseIterable {
    case continuous
    case punctual
}

enum DeadlineRecurrence: String, Codable, CaseIterable {
    case daily
    case everyTwoDays
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
}

extension DeadlineRecurrence {
    var isExclusive: Bool {
        self == .daily || self == .everyTwoDays
    }

    var weekday: Int? {
        switch self {
        case .daily, .everyTwoDays:
            return nil
        case .monday:
            return 2
        case .tuesday:
            return 3
        case .wednesday:
            return 4
        case .thursday:
            return 5
        case .friday:
            return 6
        case .saturday:
            return 7
        case .sunday:
            return 1
        }
    }

    var titleKey: String {
        switch self {
        case .daily:
            return "task.recurrence.daily"
        case .everyTwoDays:
            return "task.recurrence.everyTwoDays"
        case .monday:
            return "task.recurrence.monday"
        case .tuesday:
            return "task.recurrence.tuesday"
        case .wednesday:
            return "task.recurrence.wednesday"
        case .thursday:
            return "task.recurrence.thursday"
        case .friday:
            return "task.recurrence.friday"
        case .saturday:
            return "task.recurrence.saturday"
        case .sunday:
            return "task.recurrence.sunday"
        }
    }
}

enum DedicationStartMode: String, Codable, CaseIterable {
    case today
    case tomorrow
    case afterDeadline
    case specificDate
}

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var perceivedDifficulty: Int
    var totalSessions: Int
    var completedSessions: Int
    var tasksQuantity: Int = 1
    var deadlineKindRawValue: String = DeadlineKind.punctual.rawValue
    var recurrenceRawValue: String = DeadlineRecurrence.daily.rawValue
    var dedicationMinutes: Int = 0
    var deadlineDate: Date
    var dedicationStartModeRawValue: String = DedicationStartMode.today.rawValue
    var dedicationStartDate: Date?
    var dedicationDependencyTaskID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var isCompleted: Bool
    var notes: String?
    var isAppleSyncEnabled: Bool = false
    var appleCalendarEventIdentifier: String?

    init(
        id: UUID = UUID(),
        title: String,
        perceivedDifficulty: Int,
        totalSessions: Int,
        completedSessions: Int = 0,
        deadlineKind: DeadlineKind = .punctual,
        recurrences: Set<DeadlineRecurrence> = [.daily],
        dedicationMinutes: Int = 0,
        deadlineDate: Date,
        dedicationStartMode: DedicationStartMode = .today,
        dedicationStartDate: Date? = nil,
        dedicationDependencyTaskID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isCompleted: Bool = false,
        notes: String? = nil,
        isAppleSyncEnabled: Bool = false,
        appleCalendarEventIdentifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.perceivedDifficulty = perceivedDifficulty
        self.totalSessions = max(totalSessions, 1)
        self.completedSessions = min(max(completedSessions, 0), max(totalSessions, 1))
        self.tasksQuantity = max(totalSessions, 1)
        self.deadlineKindRawValue = deadlineKind.rawValue
        self.recurrenceRawValue = Self.rawValue(for: recurrences)
        self.dedicationMinutes = max(dedicationMinutes, 0)
        self.deadlineDate = deadlineDate
        self.dedicationStartModeRawValue = dedicationStartMode.rawValue
        self.dedicationStartDate = dedicationStartDate
        self.dedicationDependencyTaskID = dedicationDependencyTaskID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isCompleted = isCompleted || completedSessions >= totalSessions
        self.notes = notes
        self.isAppleSyncEnabled = isAppleSyncEnabled
        self.appleCalendarEventIdentifier = appleCalendarEventIdentifier
    }
}

extension TaskItem {
    var deadlineKind: DeadlineKind {
        get { DeadlineKind(rawValue: deadlineKindRawValue) ?? .punctual }
        set { deadlineKindRawValue = newValue.rawValue }
    }

    var dedicationStartMode: DedicationStartMode {
        get { DedicationStartMode(rawValue: dedicationStartModeRawValue) ?? .today }
        set { dedicationStartModeRawValue = newValue.rawValue }
    }

    var recurrence: DeadlineRecurrence {
        get { recurrences.first ?? .daily }
        set { recurrences = [newValue] }
    }

    var recurrences: Set<DeadlineRecurrence> {
        get {
            let values = recurrenceRawValue
                .split(separator: ",")
                .compactMap { DeadlineRecurrence(rawValue: String($0)) }

            return Set(values).normalizedRecurrences
        }
        set {
            recurrenceRawValue = TaskItem.rawValue(for: newValue)
        }
    }

    var progress: Double {
        let totalTasks = max(tasksQuantity, 1)
        return Double(min(completedSessions, totalTasks)) / Double(totalTasks)
    }

    var remainingSessions: Int {
        max(max(tasksQuantity, totalSessions) - completedSessions, 0)
    }

    var daysUntilDeadline: Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: deadlineDate)
        ).day ?? 0
    }

    var chaosScore: Int {
        ChaosCalculator.chaosScore(for: self)
    }

    var chaosLevel: ChaosLevel {
        ChaosLevel(value: chaosScore)
    }

    var isPastDeadline: Bool {
        deadlineDate <= .now
    }

    private static func rawValue(for recurrences: Set<DeadlineRecurrence>) -> String {
        recurrences.normalizedRecurrences
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.rawValue)
            .joined(separator: ",")
    }
}

extension Set where Element == DeadlineRecurrence {
    var normalizedRecurrences: Set<DeadlineRecurrence> {
        if contains(.daily) {
            return [.daily]
        }

        if contains(.everyTwoDays) {
            return [.everyTwoDays]
        }

        return isEmpty ? [.daily] : self
    }
}
