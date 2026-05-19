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

    static func overallChaos(for tasks: [TaskItem], asOf date: Date = .now) -> Int {
        let activeTasks = tasks.filter { !$0.isCompleted && !$0.isPastDeadline && $0.remainingSessions > 0 }
        guard !activeTasks.isEmpty else { return 0 }

        let totalChaos = activeTasks.reduce(0) { $0 + Double(chaosScore(for: $1, asOf: date)) }
        return Int((totalChaos / Double(activeTasks.count)).rounded())
    }

    static func projectedWeeklyIntensity(for tasks: [TaskItem], from date: Date = .now) -> [WeeklyIntensityPoint] {
        let calendar = Calendar.current

        return (0..<7).compactMap { offset in
            guard let projectedDate = calendar.date(byAdding: .day, value: offset, to: date) else { return nil }
            return WeeklyIntensityPoint(
                date: projectedDate,
                value: overallChaos(for: tasks, asOf: projectedDate)
            )
        }
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
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
