import Foundation
import SwiftData

enum HistoryEntryType: String, Codable, CaseIterable {
    case taskCreated
    case taskEdited
    case sessionCompleted
    case taskCompleted
}

@Model
final class HistoryEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var type: HistoryEntryType
    var message: String
    var relatedTaskTitle: String?
    var chaosValue: Int

    init(
        id: UUID = UUID(),
        date: Date = .now,
        type: HistoryEntryType,
        message: String,
        relatedTaskTitle: String? = nil,
        chaosValue: Int
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.message = message
        self.relatedTaskTitle = relatedTaskTitle
        self.chaosValue = chaosValue
    }
}
