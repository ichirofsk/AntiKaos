import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.deadlineDate, order: .forward) private var tasks: [TaskItem]
    @Query(sort: \GeneratedTaskItem.scheduledDate, order: .forward) private var generatedTasks: [GeneratedTaskItem]

    @State private var editorRoute: TaskEditorRoute?

    init() {}

    private var activeTasks: [TaskItem] {
        tasks
            .filter { !$0.isPastDeadline && $0.remainingSessions > 0 }
            .sorted { lhs, rhs in
                if lhs.deadlineDate != rhs.deadlineDate {
                    return lhs.deadlineDate < rhs.deadlineDate
                }

                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var completedTasks: [TaskItem] {
        tasks
            .filter { $0.isPastDeadline && $0.remainingSessions > 0 }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.deadlineDate < rhs.deadlineDate
            }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(AppStrings.localized("tasks.title"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 4)

                    if activeTasks.isEmpty && completedTasks.isEmpty {
                        emptyState
                    } else {
                        ForEach(activeTasks) { task in
                            TaskCard(
                                task: task,
                                canCompleteSession: canCompleteSession(for: task),
                                overdueTaskCount: overdueTaskCount(for: task),
                                nextActivityDate: nextActivityDate(for: task),
                                onCompleteSession: {
                                    withAnimation(.snappy) {
                                        TaskManager(modelContext: modelContext).completeSession(for: task)
                                    }
                                },
                                onCompleteTask: {
                                    withAnimation(.snappy) {
                                        TaskManager(modelContext: modelContext).completeTask(task)
                                    }
                                },
                                onEdit: {
                                    editorRoute = .edit(task)
                                },
                                onDelete: {
                                    withAnimation(.snappy) {
                                        TaskManager(modelContext: modelContext).deleteTask(task)
                                    }
                                }
                            )
                        }
                    }

                    if !completedTasks.isEmpty {
                        Text(AppStrings.localized("tasks.completed.section"))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)

                        ForEach(completedTasks) { task in
                            TaskCard(
                                task: task,
                                overdueTaskCount: overdueTaskCount(for: task),
                                nextActivityDate: nextActivityDate(for: task),
                                onCompleteSession: {},
                                onCompleteTask: {
                                    withAnimation(.snappy) {
                                        TaskManager(modelContext: modelContext).completeTask(task)
                                    }
                                },
                                onEdit: {
                                    editorRoute = .edit(task)
                                },
                                onDelete: {
                                    withAnimation(.snappy) {
                                        TaskManager(modelContext: modelContext).deleteTask(task)
                                    }
                                }
                            )
                            .opacity(0.82)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    CalendarView()
                } label: {
                    Image(systemName: "calendar")
                }

                Button {
                    editorRoute = .create
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editorRoute) { route in
            EditTaskView(task: route.task) { formData in
                let manager = TaskManager(modelContext: modelContext)
                withAnimation(.snappy) {
                    if let task = route.task {
                        manager.updateTask(task, with: formData)
                    } else {
                        manager.createTask(from: formData)
                    }
                }
                editorRoute = nil
            }
            .presentationDetents([.large])
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStrings.localized("tasks.empty.title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)

            Text(AppStrings.localized("tasks.empty.body"))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .softCard()
    }

    private func canCompleteSession(for task: TaskItem) -> Bool {
        guard task.deadlineKind == .continuous else {
            return !task.isCompleted
        }

        return generatedTasks.contains { generatedTask in
            generatedTask.parentTaskID == task.id
                && Calendar.current.isDate(generatedTask.scheduledDate, inSameDayAs: .now)
                && !generatedTask.isCompleted
        }
    }

    private func overdueTaskCount(for task: TaskItem) -> Int {
        guard task.deadlineKind == .continuous else { return 0 }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)

        return generatedTasks.filter { generatedTask in
            generatedTask.parentTaskID == task.id
                && generatedTask.scheduledDate < startOfToday
                && !generatedTask.isCompleted
        }.count
    }

    private func nextActivityDate(for task: TaskItem) -> Date? {
        guard task.deadlineKind == .continuous else { return nil }

        let startOfToday = Calendar.current.startOfDay(for: .now)

        return generatedTasks
            .filter { generatedTask in
                generatedTask.parentTaskID == task.id
                    && generatedTask.scheduledDate >= startOfToday
                    && !generatedTask.isCompleted
            }
            .map(\.scheduledDate)
            .min()
    }
}

private enum TaskEditorRoute: Identifiable {
    case create
    case edit(TaskItem)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let task):
            return task.id.uuidString
        }
    }

    var task: TaskItem? {
        switch self {
        case .create:
            return nil
        case .edit(let task):
            return task
        }
    }
}

#Preview {
    NavigationStack {
        TasksView()
            .modelContainer(TaskManager.previewContainer)
    }
}
