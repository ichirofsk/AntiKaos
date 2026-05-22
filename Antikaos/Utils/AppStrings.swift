import Foundation

enum AppStrings {
    static func localized(_ key: String) -> String {
        switch key {
        case "createTask.title":
            return "Criar deadline"
        case "dashboard.todo":
            return "To-do"
        default:
            return NSLocalizedString(key, comment: "")
        }
    }

    static func integerValue(_ value: Int) -> String {
        String(value)
    }

    static func scoreValue(_ value: Int) -> String {
        formatted("common.score.value", value)
    }

    static func scoreCompact(_ value: Int) -> String {
        formatted("common.score.compact", value)
    }

    static func sessionsValue(completed: Int, total: Int) -> String {
        String.localizedStringWithFormat(localized("task.sessions.value"), completed, total)
    }

    static func tasksQuantity(_ value: Int) -> String {
        String.localizedStringWithFormat(localized("task.quantity.value"), value)
    }

    static func overdueTasks(_ value: Int) -> String {
        String.localizedStringWithFormat(localized("task.delay.overdue"), value)
    }

    static func nextActivity(days: Int) -> String {
        String.localizedStringWithFormat(localized("task.nextActivity.days"), days)
    }

    static func historyCreated(_ title: String) -> String {
        String(format: localized("history.message.created"), locale: Locale.current, title)
    }

    static func historyEdited(_ title: String) -> String {
        String(format: localized("history.message.edited"), locale: Locale.current, title)
    }

    static func historySessionCompleted(_ title: String) -> String {
        String(format: localized("history.message.sessionCompleted"), locale: Locale.current, title)
    }

    static func historyCompleted(_ title: String) -> String {
        String(format: localized("history.message.completed"), locale: Locale.current, title)
    }

    static func generatedTaskTitle(minutes: Int, deadlineTitle: String) -> String {
        String(format: localized("generatedTask.title"), locale: Locale.current, minutes, deadlineTitle)
    }

    static func headerDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d MMMM")
        return formatter.string(from: date).capitalized
    }

    static func headerTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    static func deadlineRelativeString(for deadline: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .full
        return formatter.localizedString(for: deadline, relativeTo: .now)
    }

    static func dashboardTaskLine(task: TaskItem) -> String {
        String(
            format: localized("dashboard.task.line"),
            locale: Locale.current,
            deadlineRelativeString(for: task.deadlineDate),
            task.completedSessions,
            task.totalSessions
        )
    }

    static func planHeader(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d MMMM")
        let value = formatter.string(from: date).capitalized
        return String(format: localized("calendar.plan.forDay"), locale: Locale.current, value)
    }

    static func historyDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private static func formatted(_ key: String, _ value: Int) -> String {
        String.localizedStringWithFormat(localized(key), value)
    }
}
