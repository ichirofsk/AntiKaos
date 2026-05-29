import EventKit
import Foundation

@MainActor
final class AppleCalendarSyncManager {
    static let shared = AppleCalendarSyncManager()

    private let store = EKEventStore()
    private let calendarName = "Antikaos"

    private init() {}

    private var hasEventAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess, .writeOnly:
            return true
        default:
            return false
        }
    }

    private var hasReminderAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .authorized, .fullAccess, .writeOnly:
            return true
        default:
            return false
        }
    }

    func sync(task: TaskItem, generatedTasks: [GeneratedTaskItem]) async {
        guard task.isAppleSyncEnabled else {
            removeAppleItems(for: task, generatedTasks: generatedTasks)
            return
        }

        let eventAccessGranted: Bool
        do {
            eventAccessGranted = try await requestEventAccess()
        } catch {
            print("Failed to request Calendar access: \(error)")
            eventAccessGranted = false
        }

        let reminderAccessGranted: Bool
        do {
            reminderAccessGranted = try await requestReminderAccess()
        } catch {
            print("Failed to request Reminders access: \(error)")
            reminderAccessGranted = false
        }

        guard eventAccessGranted || reminderAccessGranted else {
            return
        }

        do {
            if eventAccessGranted,
               let eventCalendar = try destinationEventCalendar() {
                try upsertDeadlineEvent(for: task, in: eventCalendar)
            }

            if reminderAccessGranted,
               let reminderCalendar = try antikaosReminderCalendar() {
                for generatedTask in generatedTasks where generatedTask.parentTaskID == task.id {
                    try upsertReminder(for: generatedTask, in: reminderCalendar)
                }
            }
        } catch {
            print("Failed to sync Apple Calendar/Reminders: \(error)")
        }
    }

    func removeAppleItems(for task: TaskItem, generatedTasks: [GeneratedTaskItem]) {
        if hasEventAccess,
           let identifier = task.appleCalendarEventIdentifier,
           let event = store.event(withIdentifier: identifier) {
            try? store.remove(event, span: .thisEvent, commit: false)
        }

        task.appleCalendarEventIdentifier = nil

        if hasReminderAccess {
            for generatedTask in generatedTasks where generatedTask.parentTaskID == task.id {
                removeReminder(identifier: generatedTask.appleReminderIdentifier)
                generatedTask.appleReminderIdentifier = nil
            }
        }

        try? store.commit()
    }

    func markReminder(identifier: String?, isCompleted: Bool) {
        guard hasReminderAccess else { return }
        guard let identifier,
              let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else {
            return
        }

        reminder.isCompleted = isCompleted
        reminder.completionDate = isCompleted ? Date() : nil
        try? store.save(reminder, commit: true)
    }

    @discardableResult
    func syncReminderCompletions(tasks: [TaskItem], generatedTasks: [GeneratedTaskItem]) -> Bool {
        guard hasReminderAccess else { return false }
        var didChange = false

        for generatedTask in generatedTasks {
            guard let identifier = generatedTask.appleReminderIdentifier,
                  let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder,
                  generatedTask.isCompleted != reminder.isCompleted else {
                continue
            }

            generatedTask.isCompleted = reminder.isCompleted
            didChange = true
        }

        guard didChange else { return false }

        for task in tasks {
            let taskGeneratedTasks = generatedTasks.filter { $0.parentTaskID == task.id }
            guard !taskGeneratedTasks.isEmpty else { continue }

            task.completedSessions = taskGeneratedTasks.filter(\.isCompleted).count
            task.tasksQuantity = taskGeneratedTasks.count
            task.totalSessions = max(taskGeneratedTasks.count, 1)
            task.isCompleted = task.completedSessions >= taskGeneratedTasks.count
            task.updatedAt = .now
        }

        return true
    }

    func externalEvents(from startDate: Date, to endDate: Date) async -> [AppleCalendarExternalEvent] {
        do {
            guard try await requestEventAccess() else { return [] }

            let antikaosCalendarID = try destinationEventCalendar()?.calendarIdentifier
            let calendars = store.calendars(for: .event)
                .filter { $0.calendarIdentifier != antikaosCalendarID }
            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)

            let events = store.events(matching: predicate)
                .filter { $0.isAllDay || $0.calendar.title.localizedCaseInsensitiveContains("feriado") || $0.calendar.title.localizedCaseInsensitiveContains("holiday") }
                .map {
                    AppleCalendarExternalEvent(
                        id: $0.eventIdentifier ?? UUID().uuidString,
                        title: $0.title,
                        date: $0.startDate,
                        isAllDay: $0.isAllDay
                    )
                }

            return deduplicatedExternalEvents(events)
                .sorted {
                    if $0.date != $1.date {
                        return $0.date < $1.date
                    }

                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
        } catch {
            return []
        }
    }

    private func deduplicatedExternalEvents(_ events: [AppleCalendarExternalEvent]) -> [AppleCalendarExternalEvent] {
        var seenKeys: Set<String> = []
        var uniqueEvents: [AppleCalendarExternalEvent] = []

        for event in events {
            let key = externalEventKey(for: event)
            guard !seenKeys.contains(key) else { continue }

            seenKeys.insert(key)
            uniqueEvents.append(event)
        }

        return uniqueEvents
    }

    private func externalEventKey(for event: AppleCalendarExternalEvent) -> String {
        let day = Calendar.current.startOfDay(for: event.date).timeIntervalSinceReferenceDate
        let normalizedTitle = event.title
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return "\(Int(day))-\(normalizedTitle)"
    }

    private func upsertDeadlineEvent(for task: TaskItem, in calendar: EKCalendar) throws {
        let event: EKEvent

        if let identifier = task.appleCalendarEventIdentifier,
           let existingEvent = store.event(withIdentifier: identifier) {
            event = existingEvent
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = calendar
        }

        event.title = "Deadline: \(task.title)"
        event.startDate = task.deadlineDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: task.deadlineDate) ?? task.deadlineDate
        event.notes = task.notes

        try store.save(event, span: .thisEvent, commit: true)
        task.appleCalendarEventIdentifier = event.eventIdentifier
    }

    private func upsertReminder(for generatedTask: GeneratedTaskItem, in calendar: EKCalendar) throws {
        let reminder: EKReminder

        if let identifier = generatedTask.appleReminderIdentifier,
           let existingReminder = store.calendarItem(withIdentifier: identifier) as? EKReminder {
            reminder = existingReminder
        } else {
            reminder = EKReminder(eventStore: store)
            reminder.calendar = calendar
        }

        reminder.title = generatedTask.title
        reminder.notes = "Antikaos"
        reminder.isCompleted = generatedTask.isCompleted
        reminder.completionDate = generatedTask.isCompleted ? Date() : nil
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: generatedTask.scheduledDate)

        try store.save(reminder, commit: true)
        generatedTask.appleReminderIdentifier = reminder.calendarItemIdentifier
    }

    private func removeReminder(identifier: String?) {
        guard let identifier,
              let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else {
            return
        }

        try? store.remove(reminder, commit: false)
    }

    private func destinationEventCalendar() throws -> EKCalendar? {
        if let defaultCalendar = store.defaultCalendarForNewEvents {
            return defaultCalendar
        }

        return store.calendars(for: .event).first
    }

    private func antikaosReminderCalendar() throws -> EKCalendar? {
        if let calendar = store.calendars(for: .reminder).first(where: { $0.title == calendarName }) {
            return calendar
        }

        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = calendarName
        calendar.source = store.sources.first(where: { $0.sourceType == .calDAV && $0.calendars(for: .reminder).isEmpty == false })
            ?? store.sources.first(where: { $0.sourceType == .local })
            ?? store.sources.first

        guard calendar.source != nil else { return nil }

        try store.saveCalendar(calendar, commit: true)
        return calendar
    }

    private func requestEventAccess() async throws -> Bool {
        if hasEventAccess { return true }

        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .notDetermined else { return false }

        if #available(iOS 17.0, *) {
            return try await store.requestFullAccessToEvents()
        }

        return try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(to: .event) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func requestReminderAccess() async throws -> Bool {
        if hasReminderAccess { return true }

        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .notDetermined else { return false }

        if #available(iOS 17.0, *) {
            return try await store.requestFullAccessToReminders()
        }

        return try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(to: .reminder) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}

struct AppleCalendarExternalEvent: Identifiable {
    let id: String
    let title: String
    let date: Date
    let isAllDay: Bool
}
