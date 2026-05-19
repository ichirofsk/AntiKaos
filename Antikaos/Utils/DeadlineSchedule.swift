import Foundation

enum DeadlineSchedule {
    static func generatedTaskDates(
        for task: TaskItem,
        from startDate: Date = .now,
        calendar: Calendar = .current
    ) -> [Date] {
        guard task.deadlineKind == .continuous,
              !task.isCompleted,
              task.deadlineDate > startDate else {
            return []
        }

        let recurrences = task.recurrences
        let startOfStartDay = calendar.startOfDay(for: startDate)
        let deadlineDay = calendar.startOfDay(for: task.deadlineDate)
        guard startOfStartDay < deadlineDay else { return [] }

        var dates: [Date] = []
        var day = startOfStartDay

        while day < deadlineDay {
            if shouldGenerateTask(on: day, startDate: startOfStartDay, recurrences: recurrences, calendar: calendar),
               let scheduledDate = date(on: day, matchingTimeOf: task.deadlineDate, calendar: calendar),
               scheduledDate >= startDate,
               scheduledDate <= task.deadlineDate {
                dates.append(scheduledDate)
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return dates
    }

    private static func shouldGenerateTask(
        on day: Date,
        startDate: Date,
        recurrences: Set<DeadlineRecurrence>,
        calendar: Calendar
    ) -> Bool {
        if recurrences.contains(.daily) {
            return true
        }

        if recurrences.contains(.everyTwoDays) {
            let daysFromStart = calendar.dateComponents([.day], from: startDate, to: day).day ?? 0
            return daysFromStart % 2 == 0
        }

        let weekday = calendar.component(.weekday, from: day)
        return recurrences.contains { recurrence in
            recurrence.weekday == weekday
        }
    }

    private static func date(on day: Date, matchingTimeOf referenceDate: Date, calendar: Calendar) -> Date? {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: referenceDate)
        var components = DateComponents()
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        return calendar.date(from: components)
    }
}
