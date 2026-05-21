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

            List {
                Text(AppStrings.localized("tasks.title"))
                    .font(AppTheme.schoolbell(34))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 4)
                    .listRowStyle()

                if activeTasks.isEmpty && completedTasks.isEmpty {
                    emptyState
                        .listRowStyle()
                } else {
                    ForEach(activeTasks) { task in
                        taskCardRow(task)
                    }
                }

                if !completedTasks.isEmpty {
                    Text(AppStrings.localized("tasks.completed.section"))
                        .font(AppTheme.schoolbell(18))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                        .listRowStyle()

                    ForEach(completedTasks) { task in
                        taskCardRow(task, isExpired: true)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSpacing(2)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    CalendarView()
                } label: {
                    Image(systemName: "calendar")
                        .foregroundStyle(AppTheme.primaryChaos)
                }

                Button {
                    editorRoute = .create
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.primaryChaos)
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
                .font(AppTheme.schoolbell(24))
                .foregroundStyle(AppTheme.primaryText)

            Text(AppStrings.localized("tasks.empty.body"))
                .font(AppTheme.schoolbell(16))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .softCard()
    }

    private func taskCardRow(_ task: TaskItem, isExpired: Bool = false) -> some View {
        TaskCard(
            task: task,
            canCompleteSession: canCompleteSession(for: task),
            overdueTaskCount: overdueTaskCount(for: task),
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
            }
        )
        .opacity(isExpired ? 0.82 : 1)
        .listRowStyle()
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteTask(task)
            } label: {
                Label(AppStrings.localized("task.card.delete"), systemImage: "trash")
            }
        }
    }

    private func deleteTask(_ task: TaskItem) {
        withAnimation(.snappy) {
            TaskManager(modelContext: modelContext).deleteTask(task)
        }
    }

    private func canCompleteSession(for task: TaskItem) -> Bool {
        return generatedTasks.contains { generatedTask in
            generatedTask.parentTaskID == task.id
                && Calendar.current.isDate(generatedTask.scheduledDate, inSameDayAs: .now)
                && !generatedTask.isCompleted
        }
    }

    private func overdueTaskCount(for task: TaskItem) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)

        return generatedTasks.filter { generatedTask in
            generatedTask.parentTaskID == task.id
                && generatedTask.scheduledDate < startOfToday
                && !generatedTask.isCompleted
        }.count
    }
}

private extension View {
    func listRowStyle() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
