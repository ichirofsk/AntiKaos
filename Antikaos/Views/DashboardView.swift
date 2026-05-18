import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \TaskItem.deadlineDate) private var tasks: [TaskItem]

    private var activeTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }
    }

    private var overallChaos: Int {
        ChaosCalculator.overallChaos(for: tasks)
    }

    private var todayFocus: [TaskItem] {
        let calendar = Calendar.current

        return activeTasks
            .sorted {
                let lhsIsTodayOrOverdue = $0.daysUntilDeadline <= 0
                let rhsIsTodayOrOverdue = $1.daysUntilDeadline <= 0

                if lhsIsTodayOrOverdue != rhsIsTodayOrOverdue {
                    return lhsIsTodayOrOverdue
                }

                let lhsSameWeek = calendar.isDate($0.deadlineDate, equalTo: .now, toGranularity: .weekOfYear)
                let rhsSameWeek = calendar.isDate($1.deadlineDate, equalTo: .now, toGranularity: .weekOfYear)

                if lhsSameWeek != rhsSameWeek {
                    return lhsSameWeek
                }

                return $0.chaosScore > $1.chaosScore
            }
            .prefix(3)
            .map { $0 }
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
                Text(AppStrings.localized("app.name"))
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(AppStrings.headerDate(.now))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Text(AppStrings.headerTime(.now))
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.74), in: Capsule())
        }
    }

    private var overviewCard: some View {
        VStack(spacing: 20) {
            ChaosCircle(value: overallChaos)

            Text(AppStrings.localized("dashboard.overview.summary"))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .softCard()
    }

    private var todoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppStrings.localized("dashboard.todo"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)

            if todayFocus.isEmpty {
                Text(AppStrings.localized("dashboard.todo.empty"))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                ForEach(todayFocus) { task in
                    HStack(spacing: 12) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isCompleted ? AppTheme.supportGreen : task.chaosLevel.tint)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.primaryText)

                            Text(AppStrings.deadlineRelativeString(for: task.deadlineDate))
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer()

                        Text(AppStrings.sessionsValue(completed: task.completedSessions, total: task.totalSessions))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
        }
        .softCard()
    }

    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppStrings.localized("dashboard.weekly"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)

            WeeklyIntensityView(points: weeklyPoints)
        }
        .softCard()
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .modelContainer(TaskManager.previewContainer)
    }
}
