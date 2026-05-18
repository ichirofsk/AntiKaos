import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.deadlineDate, order: .forward) private var tasks: [TaskItem]

    @State private var editorRoute: TaskEditorRoute?

    init() {}

    private var activeTasks: [TaskItem] {
        tasks
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                if lhs.deadlineDate != rhs.deadlineDate {
                    return lhs.deadlineDate < rhs.deadlineDate
                }

                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var completedTasks: [TaskItem] {
        tasks
            .filter { $0.isCompleted }
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
                    if activeTasks.isEmpty {
                        emptyState
                    } else {
                        ForEach(activeTasks) { task in
                            TaskCard(
                                task: task,
                                onCompleteSession: {
                                    withAnimation(.snappy) {
                                        TaskManager(modelContext: modelContext).completeSession(for: task)
                                    }
                                },
                                onEdit: {
                                    editorRoute = .edit(task)
                                }
                            )
                        }
                    }

                    if !completedTasks.isEmpty {
                        Text(AppStrings.localized("tasks.completed.section"))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)

                        ForEach(completedTasks) { task in
                            TaskCard(
                                task: task,
                                onCompleteSession: {},
                                onEdit: {
                                    editorRoute = .edit(task)
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
        .navigationTitle(AppStrings.localized("tasks.title"))
        .navigationBarTitleDisplayMode(.large)
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
