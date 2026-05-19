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
            dedicationMinutes: formData.dedicationMinutes,
            deadlineDate: formData.deadlineDate,
            isCompleted: formData.completedSessions >= formData.totalSessions,
            notes: formData.normalizedNotes
        )

        modelContext.insert(task)
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
        task.totalSessions = max(formData.totalSessions, 1)
        task.completedSessions = min(max(formData.completedSessions, 0), task.totalSessions)
        task.dedicationMinutes = max(formData.dedicationMinutes, 0)
        task.deadlineDate = formData.deadlineDate
        task.notes = formData.normalizedNotes
        task.updatedAt = .now
        task.isCompleted = task.completedSessions >= task.totalSessions

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

        saveContext()
    }

    func deleteTask(_ task: TaskItem) {
        modelContext.delete(task)
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
            HistoryEntry.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        seedSampleDataIfNeeded(in: container.mainContext)
        return container
    }
}
