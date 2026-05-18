import Foundation

enum ChaosCalculator {
    private static let timeWindowInDays = 21.0

    static func chaosScore(for task: TaskItem, asOf date: Date = .now) -> Int {
        guard !task.isCompleted else { return 0 }

        let difficultyWeight = clamp(Double(task.perceivedDifficulty), lower: 0, upper: 100)
        let totalSessions = max(task.totalSessions, 1)
        let completedSessions = min(max(task.completedSessions, 0), totalSessions)

        let progressRatio = Double(completedSessions) / Double(totalSessions)
        let progressPressure = (1 - progressRatio) * 100

        let calendar = Calendar.current
        let daysRemaining = max(
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: date),
                to: calendar.startOfDay(for: task.deadlineDate)
            ).day ?? 0,
            0
        )

        // Tempo já dedicado não existe como horas no modelo,
        // então usamos sessões concluídas como proxy de avanço real.
        let normalizedDeadlinePressure = 1 - min(Double(daysRemaining), timeWindowInDays) / timeWindowInDays
        let timePressure = pow(normalizedDeadlinePressure, 0.72) * 100

        let rawChaos =
            (difficultyWeight * 0.45) +
            (timePressure * 0.35) +
            (progressPressure * 0.20)

        return Int(clamp(rawChaos.rounded(), lower: 0, upper: 100))
    }

    static func overallChaos(for tasks: [TaskItem], asOf date: Date = .now) -> Int {
        let activeTasks = tasks.filter { !$0.isCompleted }
        guard !activeTasks.isEmpty else { return 0 }

        let weightedScores = activeTasks.map { task -> (score: Double, weight: Double) in
            let score = Double(chaosScore(for: task, asOf: date))
            let weight = 0.6 + (Double(task.perceivedDifficulty) / 100) + (Double(task.totalSessions) / 12)
            return (score, weight)
        }

        let totalWeight = weightedScores.reduce(0) { $0 + $1.weight }
        let weightedSum = weightedScores.reduce(0) { $0 + ($1.score * $1.weight) }
        return Int((weightedSum / max(totalWeight, 1)).rounded())
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
}
