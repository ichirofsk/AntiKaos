import SwiftUI
import SwiftData
import Combine

struct DashboardView: View {
    @AppStorage("profile.userName") private var userName = ""
    @Query(sort: \TaskItem.deadlineDate) private var tasks: [TaskItem]
    @Query(sort: \GeneratedTaskItem.scheduledDate) private var generatedTasks: [GeneratedTaskItem]
    @State private var currentDate = Date.now

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

    private var greetingName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var todayFocus: [TodayTodoEntry] {
        let calendar = Calendar.current

        return generatedTasks
            .filter { calendar.isDate($0.scheduledDate, inSameDayAs: currentDate) }
            .map {
                TodayTodoEntry(
                    id: "generated-\($0.id.uuidString)",
                    parentTaskID: $0.parentTaskID,
                    title: $0.title,
                    date: $0.scheduledDate,
                    isCompleted: $0.isCompleted
                )
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted {
                    return $0.isCompleted && !$1.isCompleted
                }

                if $0.date != $1.date {
                    return $0.date < $1.date
                }

                return $0.title < $1.title
            }
    }

    private var todayDotStatuses: [Bool] {
        let completedCount = todayFocus.filter(\.isCompleted).count
        let pendingCount = todayFocus.count - completedCount

        return Array(repeating: true, count: completedCount) + Array(repeating: false, count: pendingCount)
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
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            currentDate = date
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                if !greetingName.isEmpty {
                    Text("Olá, \(greetingName)")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.black)
                }

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
                TodayTodoView()
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
                LazyVGrid(columns: todoDotColumns, alignment: .leading, spacing: 10) {
                    ForEach(Array(todayDotStatuses.enumerated()), id: \.offset) { _, isCompleted in
                        TodoStatusDot(isCompleted: isCompleted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .softCard()
    }

    private var todoDotColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 10, maximum: 10), spacing: 10, alignment: .leading)]
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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.deadlineDate) private var deadlineTasks: [TaskItem]
    @Query(sort: \GeneratedTaskItem.scheduledDate) private var generatedTasks: [GeneratedTaskItem]
    @State private var currentDate = Date.now

    private var tasks: [TodayTodoEntry] {
        let calendar = Calendar.current

        return generatedTasks
            .filter { calendar.isDate($0.scheduledDate, inSameDayAs: currentDate) }
            .map {
                TodayTodoEntry(
                    id: "generated-\($0.id.uuidString)",
                    parentTaskID: $0.parentTaskID,
                    title: $0.title,
                    date: $0.scheduledDate,
                    isCompleted: $0.isCompleted
                )
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted {
                    return !$0.isCompleted && $1.isCompleted
                }

                if $0.date != $1.date {
                    return $0.date < $1.date
                }

                return $0.title < $1.title
            }
    }

    private var didCompleteMission: Bool {
        !tasks.isEmpty && tasks.allSatisfy(\.isCompleted)
    }

    private var nextActivityDate: Date? {
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: currentDate)) ?? currentDate

        return generatedTasks
            .filter { $0.scheduledDate >= startOfTomorrow && !$0.isCompleted }
            .map(\.scheduledDate)
            .min()
    }

    private var emptyTodoMessage: String {
        guard let nextActivityDate else {
            return AppStrings.localized("task.nextActivity.none")
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: currentDate)
        let startOfActivityDay = calendar.startOfDay(for: nextActivityDate)
        let dayCount = max(calendar.dateComponents([.day], from: startOfToday, to: startOfActivityDay).day ?? 0, 0)

        if dayCount == 1 {
            return AppStrings.localized("task.nextActivity.tomorrow")
        }

        return AppStrings.nextActivity(days: dayCount)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("To-do")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 4)

                    if tasks.isEmpty {
                        Text(emptyTodoMessage)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .softCard()
                    } else {
                        if didCompleteMission {
                            Text(AppStrings.localized("dashboard.todo.missionComplete"))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.supportGreen)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .softCard()
                        }

                        ForEach(tasks) { task in
                            HStack(spacing: 12) {
                                if !task.isCompleted {
                                    Button {
                                        complete(task)
                                    } label: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(Color.white)
                                            .frame(width: 58, height: 58)
                                            .background(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .fill(AppTheme.supportGreen)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(AppStrings.localized("task.card.confirmActivity"))
                                }

                                HStack(spacing: 12) {
                                    TodoStatusDot(isCompleted: task.isCompleted)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(AppTheme.primaryText)

                                        Text(AppStrings.deadlineRelativeString(for: task.date))
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .softCard()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            currentDate = date
        }
    }

    private func complete(_ task: TodayTodoEntry) {
        guard !task.isCompleted,
              let parentTask = deadlineTasks.first(where: { $0.id == task.parentTaskID }) else {
            return
        }

        withAnimation(.snappy) {
            TaskManager(modelContext: modelContext).completeSession(for: parentTask)
        }
    }
}

private struct TodayTodoEntry: Identifiable {
    let id: String
    let parentTaskID: UUID
    let title: String
    let date: Date
    let isCompleted: Bool
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
                isBlinking = false

                if !isCompleted {
                    isBlinking = true
                }
            }
            .onChange(of: isCompleted) { _, newValue in
                withAnimation(newValue ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isBlinking = !newValue
                }
            }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .modelContainer(TaskManager.previewContainer)
    }
}
