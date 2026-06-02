import Foundation

enum DeadlinePriority {
    static let nearDeadlineDayLimit = 3
    static let highDifficultyThreshold = 61

    static func weight(for task: TaskItem, asOf date: Date = .now, calendar: Calendar = .current) -> Int {
        let isNear = daysUntilDeadline(for: task, asOf: date, calendar: calendar) <= nearDeadlineDayLimit
        let isDifficult = task.perceivedDifficulty >= highDifficultyThreshold

        switch (isNear, isDifficult) {
        case (true, true):
            return 4
        case (true, false):
            return 3
        case (false, true):
            return 2
        case (false, false):
            return 1
        }
    }

    static func weightedDifficulty(for task: TaskItem, asOf date: Date = .now, calendar: Calendar = .current) -> Double {
        Double(weight(for: task, asOf: date, calendar: calendar)) * Double(max(task.perceivedDifficulty, 1))
    }

    private static func daysUntilDeadline(for task: TaskItem, asOf date: Date, calendar: Calendar) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: task.deadlineDate)
        ).day ?? 0
    }
}
