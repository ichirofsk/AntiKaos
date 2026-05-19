import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \TaskItem.deadlineDate) private var tasks: [TaskItem]
    let onOpenFocusMode: () -> Void

    init(onOpenFocusMode: @escaping () -> Void = {}) {
        self.onOpenFocusMode = onOpenFocusMode
    }

    private var activeTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }
    }

    private var overallChaos: Int {
        ChaosCalculator.overallChaos(for: tasks)
    }

    private var todayFocus: [TaskItem] {
        let calendar = Calendar.current

        return tasks
            .filter { calendar.isDate($0.deadlineDate, inSameDayAs: .now) }
            .sorted {
                if $0.deadlineDate != $1.deadlineDate {
                    return $0.deadlineDate < $1.deadlineDate
                }

                return $0.title < $1.title
            }
    }

    private var weeklyPoints: [WeeklyIntensityPoint] {
        ChaosCalculator.projectedWeeklyIntensity(for: activeTasks)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    overviewCard
                    todoCard
                    weeklyCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppStrings.headerDate(.now))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var overviewCard: some View {
        VStack {
            ChaosCircle(value: overallChaos)
        }
        .frame(maxWidth: .infinity)
        .softCard()
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenFocusMode)
    }

    private var todoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink {
                TodayTodoView(tasks: todayFocus)
            } label: {
                Text(AppStrings.localized("dashboard.todo"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)

            if todayFocus.isEmpty {
                Text(AppStrings.localized("dashboard.todo.empty"))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                HStack(spacing: 10) {
                    ForEach(todayFocus) { task in
                        TodoStatusDot(isCompleted: task.isCompleted)
                    }

                    Spacer()
                }
            }
        }
        .softCard()
    }

    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppStrings.localized("dashboard.weekly"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.black)

            WeeklyIntensityView(points: weeklyPoints)
        }
        .softCard()
    }
}

private struct TodayTodoView: View {
    let tasks: [TaskItem]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if tasks.isEmpty {
                        Text(AppStrings.localized("dashboard.todo.empty"))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .softCard()
                    } else {
                        ForEach(tasks) { task in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 10, height: 10)
                                    .overlay {
                                        TodoStatusDot(isCompleted: task.isCompleted)
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.primaryText)

                                    Text(AppStrings.deadlineRelativeString(for: task.deadlineDate))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }

                                Spacer()
                            }
                            .softCard()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle(AppStrings.localized("dashboard.todo"))
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct TodoStatusDot: View {
    let isCompleted: Bool
    @State private var isBlinking = false

    var body: some View {
        Circle()
            .fill(isCompleted ? AppTheme.supportGreen : Color(red: 0.92, green: 0.12, blue: 0.16))
            .frame(width: 10, height: 10)
            .opacity(isCompleted ? 1 : (isBlinking ? 0.34 : 1))
            .scaleEffect(isCompleted ? 1 : (isBlinking ? 0.82 : 1))
            .animation(
                isCompleted ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isBlinking
            )
            .onAppear {
                if !isCompleted {
                    isBlinking = true
                }
            }
            .onChange(of: isCompleted) { _, newValue in
                isBlinking = !newValue
            }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .modelContainer(TaskManager.previewContainer)
    }
}
