import Foundation
import UserNotifications

enum NotificationManager {
    nonisolated private static let deadlinePrefix = "deadline."
    nonisolated private static let generatedTaskPrefix = "generated."

    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }

            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    static func sync(tasks: [TaskItem], generatedTasks: [GeneratedTaskItem]) {
        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { requests in
            let existingIdentifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(deadlinePrefix) || $0.hasPrefix(generatedTaskPrefix) }

            center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)

            let deadlineRequests = tasks
                .filter { !$0.isCompleted && $0.deadlineDate > .now }
                .prefix(32)
                .map(deadlineRequest(for:))

            let generatedRequests = generatedTasks
                .filter { !$0.isCompleted && $0.scheduledDate > .now }
                .prefix(32)
                .compactMap(generatedTaskRequest(for:))

            for request in deadlineRequests + generatedRequests {
                center.add(request) { _ in }
            }
        }
    }

    nonisolated private static func deadlineRequest(for task: TaskItem) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Deadline chegando"
        content.body = task.title
        content.sound = .default

        let reminderDate = Calendar.current.date(byAdding: .hour, value: -2, to: task.deadlineDate)
        let triggerDate = if let reminderDate, reminderDate > .now {
            reminderDate
        } else {
            task.deadlineDate
        }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: deadlinePrefix + task.id.uuidString,
            content: content,
            trigger: trigger
        )
    }

    nonisolated private static func generatedTaskRequest(for task: GeneratedTaskItem) -> UNNotificationRequest? {
        guard let triggerDate = Calendar.current.date(byAdding: .minute, value: -15, to: task.scheduledDate),
              triggerDate > .now else {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.title = "Hora da tarefa"
        content.body = task.title
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: generatedTaskPrefix + task.id.uuidString,
            content: content,
            trigger: trigger
        )
    }
}
