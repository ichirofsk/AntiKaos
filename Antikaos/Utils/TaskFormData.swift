import Foundation

struct TaskFormData {
    let title: String
    let perceivedDifficulty: Int
    let totalSessions: Int
    let completedSessions: Int
    let deadlineDate: Date
    let notes: String

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedNotes: String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
