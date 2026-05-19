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
            notes: formData.normalizedNotes
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
    }

    func completeSession(for task: TaskItem) {
        guard !task.isCompleted else { return }

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

    func completeTask(_ task: TaskItem) {
        guard !task.isCompleted else { return }

        addHistory(
            type: .taskCompleted,
            message: AppStrings.historyCompleted(task.title),
            relatedTaskTitle: task.title,
            chaosValue: task.chaosScore
        )
        modelContext.delete(task)
        rebuildGeneratedTasks()

        saveContext()
    }

    func deleteTask(_ task: TaskItem) {
        modelContext.delete(task)
        rebuildGeneratedTasks()
        saveContext()
    }

    func rebalanceGeneratedTasks() {
        rebuildGeneratedTasks()
        saveContext()
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
        } catch {
            assertionFailure("Failed to save context: \(error)")
        }
    }

    private func rebuildGeneratedTasks() {
        let existingGeneratedTasks = fetchGeneratedTasks()
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
        var continuousTasks: [TaskItem] = []
        var generatedCountByTaskID: [UUID: Int] = [:]
        var completedCountByTaskID: [UUID: Int] = [:]

        for task in allTasks {
            guard task.deadlineKind == .continuous,
                  !task.isCompleted,
                  task.deadlineDate > .now else {
                task.tasksQuantity = task.deadlineKind == .continuous ? 0 : task.totalSessions
                continue
            }

            let scheduledDates = DeadlineSchedule.generatedTaskDates(for: task, from: .now)
            continuousTasks.append(task)

            task.tasksQuantity = 0
            task.totalSessions = 1
            task.completedSessions = 0
            task.isCompleted = false

            for scheduledDate in scheduledDates {
                candidates.append(
                    GeneratedTaskCandidate(
                        task: task,
                        scheduledDate: scheduledDate,
                        baseMinutes: dedicationMinutes(for: task.perceivedDifficulty)
                    )
                )
            }
        }

        let candidatesByDay = Dictionary(grouping: candidates) {
            Calendar.current.startOfDay(for: $0.scheduledDate)
        }

        for (day, dayCandidates) in candidatesByDay {
            let availableMinutes = availableMinutes(on: day, availableHours: availableHours)
            let deliveryReserveMinutes = deadlineDeliveryReserveMinutes(on: day, tasks: allTasks)
            let distributableMinutes = max(availableMinutes - deliveryReserveMinutes, 0)
            let minutesByKey = dedicationMinutesByCandidate(for: dayCandidates, availableMinutes: distributableMinutes)

            for candidate in dayCandidates {
                let key = generatedTaskKey(parentTaskID: candidate.task.id, scheduledDate: candidate.scheduledDate)
                let minutes = minutesByKey[key] ?? candidate.baseMinutes
                let isCompleted = completedKeys.contains(key)

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
                        isCompleted: isCompleted
                    )
                )
            }
        }

        for task in continuousTasks {
            let generatedCount = generatedCountByTaskID[task.id, default: 0]
            let completedCount = completedCountByTaskID[task.id, default: 0]

            task.tasksQuantity = generatedCount
            task.totalSessions = max(generatedCount, 1)
            task.completedSessions = min(completedCount, generatedCount)
            task.isCompleted = generatedCount > 0 && task.completedSessions >= generatedCount
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
        let hours = availableHours?.horas(for: day) ?? modelHorasDisponiveis().horas(for: day)
        return max(hours, 0) * 60
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

    private func completeTodayGeneratedTask(for task: TaskItem) {
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
            return
        }

        todayTask.isCompleted = true
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
}

private struct GeneratedTaskAllocation {
    let key: String
    let difficulty: Int
    let remainder: Double
    var minutes: Int
}
