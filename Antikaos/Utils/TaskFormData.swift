import Foundation

struct TaskFormData {
    let title: String
    let perceivedDifficulty: Int
    let deadlineKind: DeadlineKind
    let recurrences: Set<DeadlineRecurrence>
    let totalSessions: Int
    let completedSessions: Int
    let dedicationMinutes: Int
    let deadlineDate: Date
    let notes: String

    init(
        title: String,
        perceivedDifficulty: Int,
        deadlineKind: DeadlineKind,
        recurrences: Set<DeadlineRecurrence> = [.daily],
        totalSessions: Int,
        completedSessions: Int,
        dedicationMinutes: Int,
        deadlineDate: Date,
        notes: String
    ) {
        self.title = title
        self.perceivedDifficulty = perceivedDifficulty
        self.deadlineKind = deadlineKind
        self.recurrences = recurrences.normalizedRecurrences
        self.totalSessions = totalSessions
        self.completedSessions = completedSessions
        self.dedicationMinutes = dedicationMinutes
        self.deadlineDate = deadlineDate
        self.notes = notes
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedNotes: String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
