import Foundation

enum ChaosCalculator {
    private static let maxNoDelayProgressBonus = 0.2
    private static let delayDivisor = 20.0

    static func chaosScore(for task: TaskItem, asOf date: Date = .now) -> Int {
        guard !task.isCompleted, task.remainingSessions > 0 else { return 0 }

        let difficulty = clamp(Double(task.perceivedDifficulty), lower: 0, upper: 100)
        let totalSessions = max(task.totalSessions, 1)
        let completedSessions = min(max(task.completedSessions, 0), totalSessions)
        let remainingSessions = max(totalSessions - completedSessions, 0)
        let progress = Double(completedSessions) / Double(totalSessions)

        let daysRemaining = daysUntilDeadline(for: task, asOf: date)
        let delay = max(Double(remainingSessions - daysRemaining), 0)
        let hasDelayedTask = delay > 0
        let noDelayMultiplier = hasDelayedTask ? 0.0 : 1.0
        let noDelayProgressBonus = min((progress * noDelayMultiplier) / 3, maxNoDelayProgressBonus)

        let rawChaos = difficulty * (1 - progress - noDelayProgressBonus) + (delay / delayDivisor)

        return Int(clamp(rawChaos.rounded(), lower: 0, upper: 100))
    }

    static func totalChaos(for tasks: [TaskItem], asOf date: Date = .now) -> Int {
        let activeTasks = activeTasksForOverload(from: tasks, asOf: date)
        guard !activeTasks.isEmpty else { return 0 }

        let totalChaos = activeTasks.reduce(0) { $0 + Double(chaosScore(for: $1, asOf: date)) }
        return Int((totalChaos / Double(activeTasks.count)).rounded())
    }

    static func realChaos(for tasks: [TaskItem], asOf date: Date = .now) -> Int {
        let activeTasks = activeTasksForOverload(from: tasks, asOf: date)
        guard !activeTasks.isEmpty else { return 0 }

        let cappedDeadlineCount = Double(min(activeTasks.count, 4))
        let multiplier = 2 - (sqrt(cappedDeadlineCount + 1) / cappedDeadlineCount)
        let rawChaos = Double(totalChaos(for: activeTasks, asOf: date)) * multiplier

        return Int(clamp(rawChaos.rounded(), lower: 0, upper: 100))
    }

    static func overallChaos(for tasks: [TaskItem], asOf date: Date = .now) -> Int {
        realChaos(for: tasks, asOf: date)
    }

    static func activeTasksForOverload(from tasks: [TaskItem], asOf date: Date = .now) -> [TaskItem] {
        tasks.filter { isActiveForOverload($0, in: tasks, asOf: date) }
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private static func isActiveForOverload(_ task: TaskItem, in tasks: [TaskItem], asOf date: Date) -> Bool {
        guard !task.isCompleted,
              task.deadlineDate > date,
              task.remainingSessions > 0 else {
            return false
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        switch task.dedicationStartMode {
        case .today:
            return true

        case .tomorrow:
            let startDate = task.dedicationStartDate
                ?? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: task.createdAt))

            guard let tomorrow = startDate else {
                return true
            }

            return today >= calendar.startOfDay(for: tomorrow)

        case .specificDate:
            guard let dedicationStartDate = task.dedicationStartDate else { return true }
            return today >= calendar.startOfDay(for: dedicationStartDate)

        case .afterDeadline:
            guard let dependencyID = task.dedicationDependencyTaskID else { return false }
            guard let dependency = tasks.first(where: { $0.id == dependencyID }) else {
                return true
            }

            return dependency.isCompleted
        }
    }

    private static func daysUntilDeadline(for task: TaskItem, asOf date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: task.deadlineDate)
        ).day ?? 0
    }
}
