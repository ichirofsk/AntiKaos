import Foundation
import SwiftData

@MainActor
struct TaskManager {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createTask(from formData: TaskFormData) {
        let task = TaskItem(
            title: formData.trimmedTitle,
            perceivedDifficulty: formData.perceivedDifficulty,
            totalSessions: formData.totalSessions,
            completedSessions: formData.completedSessions,
            deadlineKind: formData.deadlineKind,
            recurrences: formData.recurrences,
            dedicationMinutes: formData.dedicationMinutes,
            deadlineDate: formData.deadlineDate,
            isCompleted: formData.completedSessions >= formData.totalSessions,
            notes: formData.normalizedNotes,
            isAppleSyncEnabled: formData.shouldSyncWithApple
        )
        task.tasksQuantity = task.deadlineKind == .continuous ? 0 : task.totalSessions

        modelContext.insert(task)
        rebuildGeneratedTasks()
        addHistory(
            type: .taskCreated,
            message: AppStrings.historyCreated(task.title),
            relatedTaskTitle: task.title,
            chaosValue: task.chaosScore
        )

        if task.isCompleted {
            addHistory(
                type: .taskCompleted,
                message: AppStrings.historyCompleted(task.title),
                relatedTaskTitle: task.title,
                chaosValue: task.chaosScore
            )
        }

        saveContext()
        syncAppleItemsForEnabledTasks()
    }

    func updateTask(_ task: TaskItem, with formData: TaskFormData) {
        let wasCompleted = task.isCompleted

        task.title = formData.trimmedTitle
        task.perceivedDifficulty = formData.perceivedDifficulty
        task.deadlineKind = formData.deadlineKind
        task.recurrences = formData.recurrences
        task.totalSessions = max(formData.totalSessions, 1)
        task.tasksQuantity = task.deadlineKind == .continuous ? 0 : task.totalSessions
        task.completedSessions = min(max(formData.completedSessions, 0), max(task.tasksQuantity, task.totalSessions))
        task.dedicationMinutes = max(formData.dedicationMinutes, 0)
        task.deadlineDate = formData.deadlineDate
        task.notes = formData.normalizedNotes
        task.isAppleSyncEnabled = formData.shouldSyncWithApple
        task.updatedAt = .now
        task.isCompleted = task.completedSessions >= task.totalSessions
        rebuildGeneratedTasks()

        addHistory(
            type: .taskEdited,
            message: AppStrings.historyEdited(task.title),
            relatedTaskTitle: task.title,
            chaosValue: task.chaosScore
        )

        if !wasCompleted && task.isCompleted {
            addHistory(
                type: .taskCompleted,
                message: AppStrings.historyCompleted(task.title),
                relatedTaskTitle: task.title,
                chaosValue: task.chaosScore
            )
        }

        saveContext()
        syncAppleItemsForEnabledTasks()
    }

    func completeSession(for task: TaskItem) {
        guard !task.isCompleted else { return }

        if completeTodayGeneratedTask(for: task) {
            return
        }

        if task.deadlineKind == .continuous {
            completeTodayGeneratedTask(for: task)
            return
        }

        task.completedSessions = min(task.completedSessions + 1, task.totalSessions)
        task.updatedAt = .now
        let didCompleteTask = task.completedSessions >= task.totalSessions
        task.isCompleted = didCompleteTask

        addHistory(
            type: .sessionCompleted,
            message: AppStrings.historySessionCompleted(task.title),
            relatedTaskTitle: task.title,
            chaosValue: task.chaosScore
        )

        if didCompleteTask {
            addHistory(
                type: .taskCompleted,
                message: AppStrings.historyCompleted(task.title),
                relatedTaskTitle: task.title,
                chaosValue: task.chaosScore
            )
            deleteGeneratedTasks(for: task)
        }

        saveContext()
    }

    func uncompleteGeneratedTask(id: UUID) {
        let descriptor = FetchDescriptor<GeneratedTaskItem>(
            predicate: #Predicate { generatedTask in
                generatedTask.id == id
            }
        )

        guard let generatedTask = (try? modelContext.fetch(descriptor))?.first,
              generatedTask.isCompleted else {
            return
        }

        generatedTask.isCompleted = false
        AppleCalendarSyncManager.shared.markReminder(identifier: generatedTask.appleReminderIdentifier, isCompleted: false)

        if let parentTask = fetchTasks().first(where: { $0.id == generatedTask.parentTaskID }) {
            parentTask.completedSessions = max(parentTask.completedSessions - 1, 0)
            parentTask.isCompleted = false
            parentTask.updatedAt = .now
        }

        saveContext()
    }

    func completeTask(_ task: TaskItem) {
        guard !task.isCompleted else { return }

        addHistory(
            type: .taskCompleted,
            message: AppStrings.historyCompleted(task.title),
            relatedTaskTitle: task.title,
            chaosValue: task.chaosScore
        )
        AppleCalendarSyncManager.shared.removeAppleItems(for: task, generatedTasks: fetchGeneratedTasks())
        modelContext.delete(task)
        rebuildGeneratedTasks()

        saveContext()
    }

    func deleteTask(_ task: TaskItem) {
        AppleCalendarSyncManager.shared.removeAppleItems(for: task, generatedTasks: fetchGeneratedTasks())
        modelContext.delete(task)
        rebuildGeneratedTasks()
        saveContext()
    }

    func rebalanceGeneratedTasks() {
        rebuildGeneratedTasks()
        saveContext()
    }

    func syncAppleReminderCompletions() {
        syncReminderCompletionsIfNeeded()
    }

    private func addHistory(
        type: HistoryEntryType,
        message: String,
        relatedTaskTitle: String?,
        chaosValue: Int
    ) {
        let entry = HistoryEntry(
            type: type,
            message: message,
            relatedTaskTitle: relatedTaskTitle,
            chaosValue: chaosValue
        )
        modelContext.insert(entry)
    }

    private func saveContext() {
        do {
            try modelContext.save()
            let currentTasks = fetchTasks()
            NotificationManager.sync(tasks: currentTasks, generatedTasks: fetchGeneratedTasks())
            WidgetSyncManager.syncChaos(from: currentTasks)
        } catch {
            assertionFailure("Failed to save context: \(error)")
        }
    }

    private func rebuildGeneratedTasks() {
        let existingGeneratedTasks = fetchGeneratedTasks()
        let appleReminderIdentifierByKey = Dictionary(
            uniqueKeysWithValues: existingGeneratedTasks.compactMap { generatedTask -> (String, String)? in
                guard let identifier = generatedTask.appleReminderIdentifier else { return nil }
                return (generatedTaskKey(parentTaskID: generatedTask.parentTaskID, scheduledDate: generatedTask.scheduledDate), identifier)
            }
        )
        let completedKeys = Set(
            existingGeneratedTasks
                .filter(\.isCompleted)
                .map { generatedTaskKey(parentTaskID: $0.parentTaskID, scheduledDate: $0.scheduledDate) }
        )

        for generatedTask in existingGeneratedTasks {
            modelContext.delete(generatedTask)
        }

        let allTasks = fetchTasks()
        let availableHours = fetchAvailableHours()
        var candidates: [GeneratedTaskCandidate] = []
        var generatedParentTasks: [TaskItem] = []
        var generatedCountByTaskID: [UUID: Int] = [:]
        var completedCountByTaskID: [UUID: Int] = [:]

        for task in allTasks {
            guard !task.isCompleted,
                  task.deadlineDate > .now else {
                task.tasksQuantity = task.deadlineKind == .continuous ? 0 : task.totalSessions
                continue
            }

            switch task.deadlineKind {
            case .continuous:
                let scheduledDates = DeadlineSchedule.generatedTaskDates(for: task, from: .now)
                generatedParentTasks.append(task)

                task.tasksQuantity = 0
                task.totalSessions = 1
                task.completedSessions = 0
                task.isCompleted = false

                for scheduledDate in scheduledDates {
                    candidates.append(
                        GeneratedTaskCandidate(
                            task: task,
                            scheduledDate: scheduledDate,
                            baseMinutes: dedicationMinutes(for: task.perceivedDifficulty),
                            usesFixedMinutes: false,
                            defaultIsCompleted: false
                        )
                    )
                }

            case .punctual:
                let completedSessions = task.completedSessions
                let scheduledDates = punctualGeneratedTaskDates(for: task, from: .now)
                generatedParentTasks.append(task)

                task.tasksQuantity = 0
                task.totalSessions = max(scheduledDates.count, 1)
                task.completedSessions = 0
                task.isCompleted = false

                for (index, scheduledDate) in scheduledDates.enumerated() {
                    candidates.append(
                        GeneratedTaskCandidate(
                            task: task,
                            scheduledDate: scheduledDate,
                            baseMinutes: task.dedicationMinutes,
                            usesFixedMinutes: true,
                            defaultIsCompleted: index < completedSessions
                        )
                    )
                }
            }
        }

        let candidatesByDay = Dictionary(grouping: candidates) {
            Calendar.current.startOfDay(for: $0.scheduledDate)
        }

        for (day, dayCandidates) in candidatesByDay {
            let availableMinutes = availableMinutes(on: day, availableHours: availableHours)
            let deliveryReserveMinutes = deadlineDeliveryReserveMinutes(on: day, tasks: allTasks)
            let fixedCandidates = dayCandidates.filter(\.usesFixedMinutes)
            let flexibleCandidates = dayCandidates.filter { !$0.usesFixedMinutes }
            let fixedMinutes = fixedCandidates.reduce(0) { $0 + $1.baseMinutes }
            let distributableMinutes = max(availableMinutes - deliveryReserveMinutes - fixedMinutes, 0)
            let minutesByKey = dedicationMinutesByCandidate(for: flexibleCandidates, availableMinutes: distributableMinutes)

            for candidate in dayCandidates {
                let key = generatedTaskKey(parentTaskID: candidate.task.id, scheduledDate: candidate.scheduledDate)
                let minutes = candidate.usesFixedMinutes ? candidate.baseMinutes : (minutesByKey[key] ?? candidate.baseMinutes)
                let isCompleted = completedKeys.contains(key) || candidate.defaultIsCompleted

                guard minutes > 0 else { continue }

                generatedCountByTaskID[candidate.task.id, default: 0] += 1
                if isCompleted {
                    completedCountByTaskID[candidate.task.id, default: 0] += 1
                }

                modelContext.insert(
                    GeneratedTaskItem(
                        parentTaskID: candidate.task.id,
                        title: AppStrings.generatedTaskTitle(minutes: minutes, deadlineTitle: candidate.task.title),
                        dedicationMinutes: minutes,
                        scheduledDate: candidate.scheduledDate,
                        isCompleted: isCompleted,
                        appleReminderIdentifier: appleReminderIdentifierByKey[key]
                    )
                )
            }
        }

        for task in generatedParentTasks {
            let generatedCount = generatedCountByTaskID[task.id, default: 0]
            let completedCount = completedCountByTaskID[task.id, default: 0]

            task.tasksQuantity = generatedCount
            task.totalSessions = max(generatedCount, 1)
            task.completedSessions = min(completedCount, generatedCount)
            task.isCompleted = generatedCount > 0 && task.completedSessions >= generatedCount
        }
    }

    private func punctualGeneratedTaskDates(for task: TaskItem, from date: Date) -> [Date] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: date)
        let deadlineDay = calendar.startOfDay(for: task.deadlineDate)
        guard startDay < deadlineDay else { return [] }

        var days: [Date] = []
        var day = startDay

        while day < deadlineDay {
            days.append(day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        let sessionCount = max(task.totalSessions, 0)
        guard sessionCount > 0 else { return [] }
        guard !days.isEmpty else { return [] }

        let uniqueSessionCount = min(sessionCount, days.count)
        guard uniqueSessionCount > 0 else { return [] }

        if uniqueSessionCount == 1 {
            return scheduledDate(on: days[0], matchingTimeOf: task.deadlineDate, calendar: calendar).map { [$0] } ?? []
        }

        var selectedIndices: [Int] = []
        for index in 0..<uniqueSessionCount {
            let rawIndex = Double(index) * Double(days.count - 1) / Double(max(uniqueSessionCount - 1, 1))
            var candidateIndex = Int(rawIndex.rounded())

            while selectedIndices.contains(candidateIndex), candidateIndex + 1 < days.count {
                candidateIndex += 1
            }

            while selectedIndices.contains(candidateIndex), candidateIndex - 1 >= 0 {
                candidateIndex -= 1
            }

            if !selectedIndices.contains(candidateIndex) {
                selectedIndices.append(candidateIndex)
            }
        }

        return selectedIndices
            .sorted()
            .compactMap { scheduledDate(on: days[$0], matchingTimeOf: task.deadlineDate, calendar: calendar) }
    }

    private func scheduledDate(on day: Date, matchingTimeOf referenceDate: Date, calendar: Calendar) -> Date? {
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

    private func scheduledDates(
        on day: Date,
        count: Int,
        matchingTimeOf referenceDate: Date,
        calendar: Calendar
    ) -> [Date] {
        guard count > 0 else { return [] }

        let referenceHour = calendar.component(.hour, from: referenceDate)
        let referenceMinute = calendar.component(.minute, from: referenceDate)
        let firstHour = max(min(referenceHour - max(count - 1, 0), 20), 7)

        return (0..<count).compactMap { index in
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = min(firstHour + index, 22)
            components.minute = referenceMinute
            components.second = 0
            return calendar.date(from: components)
        }
    }

    private func fetchTasks() -> [TaskItem] {
        (try? modelContext.fetch(FetchDescriptor<TaskItem>())) ?? []
    }

    private func fetchGeneratedTasks() -> [GeneratedTaskItem] {
        (try? modelContext.fetch(FetchDescriptor<GeneratedTaskItem>())) ?? []
    }

    private func fetchAvailableHours() -> modelHorasDisponiveis? {
        var descriptor = FetchDescriptor<modelHorasDisponiveis>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func availableMinutes(on date: Date, availableHours: modelHorasDisponiveis?) -> Int {
        let day = availableWeekday(for: date)
        return availableHours?.minutes(for: day) ?? modelHorasDisponiveis().minutes(for: day)
    }

    private func deadlineDeliveryReserveMinutes(on date: Date, tasks: [TaskItem]) -> Int {
        let deadlineCount = tasks.filter { task in
            !task.isCompleted && Calendar.current.isDate(task.deadlineDate, inSameDayAs: date)
        }.count

        return deadlineCount * 60
    }

    private func availableWeekday(for date: Date) -> AvailableWeekday {
        switch Calendar.current.component(.weekday, from: date) {
        case 1:
            return .domingo
        case 2:
            return .segunda
        case 3:
            return .terca
        case 4:
            return .quarta
        case 5:
            return .quinta
        case 6:
            return .sexta
        default:
            return .sabado
        }
    }

    private func dedicationMinutesByCandidate(
        for candidates: [GeneratedTaskCandidate],
        availableMinutes: Int
    ) -> [String: Int] {
        let baseTotal = candidates.reduce(0) { $0 + $1.baseMinutes }
        guard baseTotal > availableMinutes else {
            return Dictionary(
                uniqueKeysWithValues: candidates.map {
                    (generatedTaskKey(parentTaskID: $0.task.id, scheduledDate: $0.scheduledDate), $0.baseMinutes)
                }
            )
        }

        guard availableMinutes > 0, !candidates.isEmpty else {
            return Dictionary(
                uniqueKeysWithValues: candidates.map {
                    (generatedTaskKey(parentTaskID: $0.task.id, scheduledDate: $0.scheduledDate), 0)
                }
            )
        }

        let totalDifficulty = candidates.reduce(0) { $0 + max($1.task.perceivedDifficulty, 0) }
        let equalWeight = totalDifficulty == 0
        let totalWeight = equalWeight ? Double(candidates.count) : Double(totalDifficulty)

        var allocations = candidates.map { candidate -> GeneratedTaskAllocation in
            let weight = equalWeight ? 1.0 : Double(max(candidate.task.perceivedDifficulty, 0))
            let rawMinutes = Double(availableMinutes) * weight / totalWeight
            let roundedMinutes = Int((rawMinutes / 10.0).rounded() * 10)

            return GeneratedTaskAllocation(
                key: generatedTaskKey(parentTaskID: candidate.task.id, scheduledDate: candidate.scheduledDate),
                difficulty: candidate.task.perceivedDifficulty,
                remainder: rawMinutes - Double(roundedMinutes),
                minutes: max(roundedMinutes, 0)
            )
        }

        while allocations.reduce(0, { $0 + $1.minutes }) > availableMinutes,
              let index = allocations.indices.max(by: { allocations[$0].minutes < allocations[$1].minutes }),
              allocations[index].minutes > 0 {
            allocations[index].minutes -= 10
        }

        while allocations.reduce(0, { $0 + $1.minutes }) + 10 <= availableMinutes,
              let index = allocations.indices.max(by: {
                  if allocations[$0].remainder == allocations[$1].remainder {
                      return allocations[$0].difficulty < allocations[$1].difficulty
                  }

                  return allocations[$0].remainder < allocations[$1].remainder
              }) {
            allocations[index].minutes += 10
        }

        return Dictionary(uniqueKeysWithValues: allocations.map { ($0.key, $0.minutes) })
    }

    private func generatedTaskKey(parentTaskID: UUID, scheduledDate: Date) -> String {
        "\(parentTaskID.uuidString)-\(Int(scheduledDate.timeIntervalSinceReferenceDate.rounded()))"
    }

    private func deleteGeneratedTasks(for task: TaskItem) {
        let parentID = task.id
        let descriptor = FetchDescriptor<GeneratedTaskItem>(
            predicate: #Predicate { generatedTask in
                generatedTask.parentTaskID == parentID
            }
        )

        guard let generatedTasks = try? modelContext.fetch(descriptor) else { return }

        for generatedTask in generatedTasks {
            modelContext.delete(generatedTask)
        }
    }

    @discardableResult
    private func completeTodayGeneratedTask(for task: TaskItem) -> Bool {
        let parentID = task.id
        let descriptor = FetchDescriptor<GeneratedTaskItem>(
            predicate: #Predicate { generatedTask in
                generatedTask.parentTaskID == parentID
            }
        )

        guard let generatedTasks = try? modelContext.fetch(descriptor),
              let todayTask = generatedTasks.first(where: { generatedTask in
                  Calendar.current.isDate(generatedTask.scheduledDate, inSameDayAs: .now)
              }),
              !todayTask.isCompleted else {
            return false
        }

        todayTask.isCompleted = true
        AppleCalendarSyncManager.shared.markReminder(identifier: todayTask.appleReminderIdentifier, isCompleted: true)
        task.completedSessions = min(task.completedSessions + 1, max(task.tasksQuantity, 1))
        task.updatedAt = .now
        let didCompleteTask = task.tasksQuantity > 0 && task.completedSessions >= task.tasksQuantity
        task.isCompleted = didCompleteTask

        addHistory(
            type: .sessionCompleted,
            message: AppStrings.historySessionCompleted(task.title),
            relatedTaskTitle: task.title,
            chaosValue: task.chaosScore
        )

        if didCompleteTask {
            addHistory(
                type: .taskCompleted,
                message: AppStrings.historyCompleted(task.title),
                relatedTaskTitle: task.title,
                chaosValue: task.chaosScore
            )
        }

        saveContext()
        return true
    }

    private func syncAppleItemsForEnabledTasks() {
        let tasks = fetchTasks()
        let generatedTasks = fetchGeneratedTasks()

        for task in tasks {
            Task { @MainActor in
                await AppleCalendarSyncManager.shared.sync(task: task, generatedTasks: generatedTasks)
                try? modelContext.save()
            }
        }
    }

    private func syncReminderCompletionsIfNeeded() {
        let tasks = fetchTasks()
        let generatedTasks = fetchGeneratedTasks()

        if AppleCalendarSyncManager.shared.syncReminderCompletions(tasks: tasks, generatedTasks: generatedTasks) {
            try? modelContext.save()
        }
    }

    private func dedicationMinutes(for perceivedDifficulty: Int) -> Int {
        let clampedDifficulty = min(max(perceivedDifficulty, 0), 100)
        let rawMinutes = 40.0 + (Double(clampedDifficulty) / 100.0 * 50.0)
        let roundedToTen = Int((rawMinutes / 10.0).rounded() * 10)
        return min(max(roundedToTen, 40), 90)
    }

    static func seedSampleDataIfNeeded(in modelContext: ModelContext) {
        let taskCount = (try? modelContext.fetchCount(FetchDescriptor<TaskItem>())) ?? 0
        let historyCount = (try? modelContext.fetchCount(FetchDescriptor<HistoryEntry>())) ?? 0

        guard taskCount == 0, historyCount == 0 else { return }

        let manager = TaskManager(modelContext: modelContext)
        let calendar = Calendar.current

        manager.createTask(
            from: TaskFormData(
                title: "Estudar cálculo",
                perceivedDifficulty: 64,
                deadlineKind: .punctual,
                totalSessions: 5,
                completedSessions: 3,
                dedicationMinutes: 45,
                deadlineDate: calendar.date(byAdding: .day, value: 4, to: .now) ?? .now,
                notes: "Capítulos 3 e 4."
            )
        )

        manager.createTask(
            from: TaskFormData(
                title: "Preparar apresentação",
                perceivedDifficulty: 78,
                deadlineKind: .punctual,
                totalSessions: 4,
                completedSessions: 1,
                dedicationMinutes: 60,
                deadlineDate: calendar.date(byAdding: .day, value: 2, to: .now) ?? .now,
                notes: "Revisar narrativa e tempo."
            )
        )

        manager.createTask(
            from: TaskFormData(
                title: "Responder e-mails",
                perceivedDifficulty: 28,
                deadlineKind: .punctual,
                totalSessions: 2,
                completedSessions: 2,
                dedicationMinutes: 20,
                deadlineDate: calendar.date(byAdding: .day, value: -1, to: .now) ?? .now,
                notes: ""
            )
        )
    }

    static func removeLegacySampleDataIfNeeded(in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<TaskItem>()
        guard let tasks = try? modelContext.fetch(descriptor), !tasks.isEmpty else { return }

        let sampleTitles: Set<String> = [
            "Estudar cálculo",
            "Preparar apresentação",
            "Responder e-mails"
        ]

        let taskTitles = Set(tasks.map(\.title))
        guard taskTitles.isSubset(of: sampleTitles) else { return }

        let generatedTasks = (try? modelContext.fetch(FetchDescriptor<GeneratedTaskItem>())) ?? []
        let historyEntries = (try? modelContext.fetch(FetchDescriptor<HistoryEntry>())) ?? []

        for task in tasks {
            modelContext.delete(task)
        }

        for generatedTask in generatedTasks {
            modelContext.delete(generatedTask)
        }

        for entry in historyEntries {
            modelContext.delete(entry)
        }

        try? modelContext.save()
    }

    static var previewContainer: ModelContainer {
        let schema = Schema([
            TaskItem.self,
            GeneratedTaskItem.self,
            HistoryEntry.self,
            modelHorasDisponiveis.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        seedSampleDataIfNeeded(in: container.mainContext)
        return container
    }
}

private struct GeneratedTaskCandidate {
    let task: TaskItem
    let scheduledDate: Date
    let baseMinutes: Int
    let usesFixedMinutes: Bool
    let defaultIsCompleted: Bool
}

private struct GeneratedTaskAllocation {
    let key: String
    let difficulty: Int
    let remainder: Double
    var minutes: Int
}
