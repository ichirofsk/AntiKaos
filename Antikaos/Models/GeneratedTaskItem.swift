import Foundation
import SwiftData

@Model
final class GeneratedTaskItem {
    @Attribute(.unique) var id: UUID
    var parentTaskID: UUID
    var title: String
    var dedicationMinutes: Int = 0
    var scheduledDate: Date
    var createdAt: Date
    var isCompleted: Bool
    var isDelayDismissed: Bool = false
    var appleReminderIdentifier: String?

    init(
        id: UUID = UUID(),
        parentTaskID: UUID,
        title: String,
        dedicationMinutes: Int = 0,
        scheduledDate: Date,
        createdAt: Date = .now,
        isCompleted: Bool = false,
        isDelayDismissed: Bool = false,
        appleReminderIdentifier: String? = nil
    ) {
        self.id = id
        self.parentTaskID = parentTaskID
        self.title = title
        self.dedicationMinutes = max(dedicationMinutes, 0)
        self.scheduledDate = scheduledDate
        self.createdAt = createdAt
        self.isCompleted = isCompleted
        self.isDelayDismissed = isDelayDismissed
        self.appleReminderIdentifier = appleReminderIdentifier
    }
}
