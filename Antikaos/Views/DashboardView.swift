import SwiftUI
import SwiftData
import Combine
import UIKit

struct DashboardView: View {
    @AppStorage("profile.userName") private var userName = ""
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.deadlineDate) private var tasks: [TaskItem]
    @Query(sort: \GeneratedTaskItem.scheduledDate) private var generatedTasks: [GeneratedTaskItem]
    @State private var currentDate = Date.now
    @State private var isTodoExpanded = false
    @State private var isShowingChaosInfo = false

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
                    generatedTaskID: $0.id,
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

    private var didCompleteMission: Bool {
        !todayFocus.isEmpty && todayFocus.allSatisfy(\.isCompleted)
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

    private var weeklyPoints: [WeeklyIntensityPoint] {
        let calendar = Calendar.current

        return (-6...0).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: currentDate) else { return nil }
            let dayTasks = generatedTasks.filter { calendar.isDate($0.scheduledDate, inSameDayAs: day) }
            let completedCount = dayTasks.filter(\.isCompleted).count

            return WeeklyIntensityPoint(
                date: day,
                stars: starCount(completedTasks: completedCount, totalTasks: dayTasks.count),
                hasTasks: !dayTasks.isEmpty
            )
        }
    }

    private var noDelayStreak: Int {
        let calendar = Calendar.current
        let completedTasks = generatedTasks.filter(\.isCompleted)

        guard let latestCompletedDate = completedTasks.map(\.scheduledDate).max() else {
            return 0
        }

        let startDay = calendar.startOfDay(for: latestCompletedDate)
        let earliestGeneratedDay = generatedTasks
            .map { calendar.startOfDay(for: $0.scheduledDate) }
            .min() ?? startDay

        var streak = 0
        var day = startDay

        while day >= earliestGeneratedDay {
            let dayTasks = generatedTasks.filter { calendar.isDate($0.scheduledDate, inSameDayAs: day) }

            if dayTasks.contains(where: { !$0.isCompleted }) {
                break
            }

            streak += 1

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }

            day = previousDay
        }

        return streak
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 390
            let isVeryCompact = proxy.size.width < 370

            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: isVeryCompact ? 18 : 24) {
                        header(isVeryCompact: isVeryCompact)
                        overviewCard(isCompact: isCompact, isVeryCompact: isVeryCompact)
                        todoCard(isCompact: isCompact, isVeryCompact: isVeryCompact)
                        weeklyCard(isCompact: isCompact, isVeryCompact: isVeryCompact)
                    }
                    .padding(.horizontal, isVeryCompact ? 16 : 20)
                    .padding(.top, isVeryCompact ? 12 : 16)
                    .padding(.bottom, 28)
                }

                if isShowingChaosInfo {
                    chaosInfoOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(2)
                }
            }
        }
        .scribbleBackground()
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.22), value: isShowingChaosInfo)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            currentDate = date
        }
        .onAppear {
            TaskManager(modelContext: modelContext).syncAppleReminderCompletions()
        }
    }

    private func header(isVeryCompact: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                if !greetingName.isEmpty {
                    Text("Olá, \(greetingName)")
                        .font(AppTheme.schoolbell(isVeryCompact ? 30 : 34))
                        .foregroundStyle(AppTheme.primaryText)
                }

                Text(AppStrings.headerDate(.now))
                    .font(AppTheme.schoolbell(isVeryCompact ? 18 : 20))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func overviewCard(isCompact: Bool, isVeryCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()

                Button {
                    isShowingChaosInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(AppTheme.primaryChaos)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Spacer()
                ChaosCircle(value: overallChaos, size: isVeryCompact ? 180 : (isCompact ? 194 : 208))
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var chaosInfoOverlay: some View {
        ZStack {
            AppTheme.background.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowingChaosInfo = false
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("O que é o caos?")
                        .font(AppTheme.schoolbell(24))
                        .foregroundStyle(AppTheme.primaryText)

                    Spacer()

                    Button {
                        isShowingChaosInfo = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryChaos)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.72))
                            )
                    }
                    .buttonStyle(.plain)
                }

                JustifiedText(
                    text: "A métrica Caos relaciona a quantidade de deadlines, o tempo restante para a finalização de cada deadline, o progresso e a dificuldade percebida em cada uma, a fim de ajudar o usuário a se localizar quanto a suas entregas, da melhor forma possível.\n\nMantenha-se em dia para não deixar o Caos tomar conta!",
                    fontSize: 16,
                    color: UIColor.black.withAlphaComponent(0.64)
                )
                .frame(maxWidth: .infinity)

                Button {
                    isShowingChaosInfo = false
                } label: {
                    Text("Entendi")
                        .font(AppTheme.schoolbell(20))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.primaryChaos)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.paper.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppTheme.primaryChaos.opacity(0.9), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 28)
        }
    }

    private func todoCard(isCompact: Bool, isVeryCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(AppStrings.localized("dashboard.todo"))
                    .font(AppTheme.schoolbell(isVeryCompact ? 24 : 28))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.24)) {
                        isTodoExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(isTodoExpanded ? "Ver menos" : "Ver mais")
                            .font(AppTheme.schoolbell(isVeryCompact ? 14 : 16))
                            .foregroundStyle(AppTheme.primaryChaos)

                        Image(systemName: isTodoExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryChaos)
                    }
                }
                .buttonStyle(.plain)
            }

            if todayFocus.isEmpty {
                Text(isTodoExpanded ? emptyTodoMessage : AppStrings.localized("dashboard.todo.empty"))
                    .font(AppTheme.schoolbell(16))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                if isTodoExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        if didCompleteMission {
                            Text(AppStrings.localized("dashboard.todo.missionComplete"))
                                .font(AppTheme.schoolbell(isVeryCompact ? 18 : 20))
                                .foregroundStyle(AppTheme.supportGreen)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 2)
                        }

                        ForEach(todayFocus) { task in
                            HStack(spacing: 12) {
                                if !task.isCompleted {
                                    Button {
                                        complete(task)
                                    } label: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: isVeryCompact ? 18 : 20, weight: .semibold))
                                            .foregroundStyle(Color.white)
                                            .frame(width: isVeryCompact ? 40 : 44, height: isVeryCompact ? 40 : 44)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(AppTheme.supportGreen)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack(spacing: 10) {
                                    TodoStatusDot(isCompleted: task.isCompleted)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(task.title)
                                            .font(AppTheme.schoolbell(isVeryCompact ? 16 : 18))
                                            .foregroundStyle(AppTheme.primaryText)
                                            .multilineTextAlignment(.leading)

                                        Text(AppStrings.deadlineRelativeString(for: task.date))
                                            .font(AppTheme.schoolbell(isVeryCompact ? 13 : 14))
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                    Spacer()

                                    if task.isCompleted {
                                        Button {
                                            uncomplete(task)
                                        } label: {
                                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                                .font(.system(size: isVeryCompact ? 18 : 20, weight: .medium))
                                                .foregroundStyle(AppTheme.primaryChaos)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.62))
                                )
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 10, maximum: 10), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 10) {
                        ForEach(Array(todayDotStatuses.enumerated()), id: \.offset) { _, isCompleted in
                            TodoStatusDot(isCompleted: isCompleted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .softCard()
    }

    private func starCount(completedTasks: Int, totalTasks: Int) -> Int {
        guard totalTasks > 0, completedTasks > 0 else { return 0 }

        let completionRate = Double(completedTasks) / Double(totalTasks)

        if completionRate == 1 {
            return 3
        }

        if completionRate >= 0.4 {
            return 2
        }

        return 1
    }

    private func complete(_ task: TodayTodoEntry) {
        guard !task.isCompleted,
              let parentTask = tasks.first(where: { $0.id == task.parentTaskID }) else {
            return
        }

        withAnimation(.snappy) {
            TaskManager(modelContext: modelContext).completeSession(for: parentTask)
        }
    }

    private func uncomplete(_ task: TodayTodoEntry) {
        guard task.isCompleted else { return }

        withAnimation(.snappy) {
            TaskManager(modelContext: modelContext).uncompleteGeneratedTask(id: task.generatedTaskID)
        }
    }

    private func weeklyCard(isCompact: Bool, isVeryCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text(AppStrings.localized("dashboard.weekly"))
                    .font(AppTheme.schoolbell(isVeryCompact ? 24 : 28))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer(minLength: 12)

                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))

                    Text("\(noDelayStreak)")
                        .font(AppTheme.schoolbell(isVeryCompact ? 16 : 18))
                }
                .foregroundStyle(AppTheme.primaryChaos)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppTheme.primaryChaos.opacity(0.12))
                )
            }

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
                    generatedTaskID: $0.id,
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
                        .font(AppTheme.schoolbell(34))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 4)

                    if tasks.isEmpty {
                        Text(emptyTodoMessage)
                            .font(AppTheme.schoolbell(16))
                            .foregroundStyle(AppTheme.secondaryText)
                            .softCard()
                    } else {
                        if didCompleteMission {
                            Text(AppStrings.localized("dashboard.todo.missionComplete"))
                                .font(AppTheme.schoolbell(24))
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
                                            .font(AppTheme.schoolbell(18))
                                            .foregroundStyle(AppTheme.primaryText)

                                        Text(AppStrings.deadlineRelativeString(for: task.date))
                                            .font(AppTheme.schoolbell(14))
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }

                                    Spacer()

                                    if task.isCompleted {
                                        Button {
                                            uncomplete(task)
                                        } label: {
                                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(AppTheme.primaryChaos)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(AppStrings.localized("task.card.undoCompletion"))
                                    }
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

    private func uncomplete(_ task: TodayTodoEntry) {
        guard task.isCompleted else { return }

        withAnimation(.snappy) {
            TaskManager(modelContext: modelContext).uncompleteGeneratedTask(id: task.generatedTaskID)
        }
    }
}

private struct TodayTodoEntry: Identifiable {
    let id: String
    let generatedTaskID: UUID
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

private struct JustifiedText: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let color: UIColor

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .justified
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 1
        paragraphStyle.paragraphSpacing = 10

        uiView.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont(name: "Schoolbell", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .modelContainer(TaskManager.previewContainer)
    }
}
