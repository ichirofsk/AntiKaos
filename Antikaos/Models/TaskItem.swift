import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var perceivedDifficulty: Int
    var totalSessions: Int
    var completedSessions: Int
    var deadlineDate: Date
    var createdAt: Date
    var updatedAt: Date
    var isCompleted: Bool
    var notes: String?

    init(
        id: UUID = UUID(),
        title: String,
        perceivedDifficulty: Int,
        totalSessions: Int,
        completedSessions: Int = 0,
        deadlineDate: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isCompleted: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.perceivedDifficulty = perceivedDifficulty
        self.totalSessions = max(totalSessions, 1)
        self.completedSessions = min(max(completedSessions, 0), max(totalSessions, 1))
        self.deadlineDate = deadlineDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isCompleted = isCompleted || completedSessions >= totalSessions
        self.notes = notes
    }
}

extension TaskItem {
    var progress: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(completedSessions) / Double(totalSessions)
    }

    var remainingSessions: Int {
        max(totalSessions - completedSessions, 0)
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
}
