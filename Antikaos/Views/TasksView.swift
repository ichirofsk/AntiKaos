import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.deadlineDate, order: .forward) private var tasks: [TaskItem]
    @Query(sort: \GeneratedTaskItem.scheduledDate, order: .forward) private var generatedTasks: [GeneratedTaskItem]

    @State private var editorRoute: TaskEditorRoute?
    @State private var selectedFilter: DeadlineFilter = .all
    @State private var isShowingLegend = false

    private var pendingTasks: [TaskItem] {
        tasks
            .filter { !$0.isCompleted && !$0.isPastDeadline && $0.remainingSessions > 0 }
            .sorted { lhs, rhs in
                if lhs.deadlineDate != rhs.deadlineDate {
                    return lhs.deadlineDate < rhs.deadlineDate
                }

                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var filteredTasks: [TaskItem] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedFilter {
        case .all:
            return pendingTasks
        case .thisWeek:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
                return pendingTasks
            }
            return pendingTasks.filter { weekInterval.contains($0.deadlineDate) }
        }
    }

    private var dueSoonCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 3, to: start) ?? start

        return pendingTasks.filter { task in
            let deadline = calendar.startOfDay(for: task.deadlineDate)
            return deadline >= start && deadline <= end
        }.count
    }

    private var impactLevel: ChaosLevel {
        ChaosLevel(value: ChaosCalculator.overallChaos(for: pendingTasks))
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 390
            let isVeryCompact = proxy.size.width < 372

            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: isVeryCompact ? 12 : (isCompact ? 14 : 18)) {
                        header(isCompact: isCompact, isVeryCompact: isVeryCompact)
                        summaryCard(isCompact: isCompact, isVeryCompact: isVeryCompact)
                        filterRow(isCompact: isCompact, isVeryCompact: isVeryCompact)
                        tasksSection(isCompact: isCompact, isVeryCompact: isVeryCompact)
                    }
                    .padding(.horizontal, isVeryCompact ? 14 : (isCompact ? 16 : 20))
                    .padding(.top, isVeryCompact ? 12 : (isCompact ? 14 : 18))
                    .padding(.bottom, 28)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }

                if isShowingLegend {
                    legendOverlay(isCompact: isCompact, isVeryCompact: isVeryCompact)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(2)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.22), value: isShowingLegend)
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

    private func header(isCompact: Bool, isVeryCompact: Bool) -> some View {
        HStack(alignment: .center) {
            Text(AppStrings.localized("tasks.title"))
                .font(AppTheme.schoolbell(isVeryCompact ? 30 : (isCompact ? 33 : 38)))
                .foregroundStyle(AppTheme.primaryText)

            Spacer(minLength: 12)

            HStack(spacing: isVeryCompact ? 8 : (isCompact ? 10 : 12)) {
                NavigationLink {
                    CalendarView()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: isVeryCompact ? 18 : (isCompact ? 20 : 22), weight: .semibold))
                        .foregroundStyle(AppTheme.primaryChaos)
                        .frame(width: isVeryCompact ? 44 : (isCompact ? 48 : 52), height: isVeryCompact ? 44 : (isCompact ? 48 : 52))
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.primaryChaos.opacity(0.26), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    editorRoute = .create
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: isVeryCompact ? 18 : (isCompact ? 20 : 22), weight: .bold))
                        .foregroundStyle(AppTheme.primaryChaos)
                        .frame(width: isVeryCompact ? 44 : (isCompact ? 48 : 52), height: isVeryCompact ? 44 : (isCompact ? 48 : 52))
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.primaryChaos.opacity(0.9), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func summaryCard(isCompact: Bool, isVeryCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: isVeryCompact ? 10 : (isCompact ? 12 : 16)) {
            HStack(alignment: .top) {
                Text("Resumo")
                    .font(AppTheme.schoolbell(isVeryCompact ? 20 : (isCompact ? 22 : 24)))
                    .foregroundStyle(AppTheme.supportGreen)

                Spacer()

                Button {
                    isShowingLegend = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: isVeryCompact ? 17 : (isCompact ? 18 : 20), weight: .medium))
                        .foregroundStyle(AppTheme.supportGreen)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                summaryMetric(
                    value: "\(pendingTasks.count)",
                    tint: AppTheme.supportGreen,
                    lineOne: "Atividades",
                    lineTwo: "pendentes",
                    isCompact: isCompact,
                    isVeryCompact: isVeryCompact
                )

                summaryDivider(isVeryCompact: isVeryCompact)

                summaryMetric(
                    value: "\(dueSoonCount)",
                    tint: AppTheme.primaryChaos,
                    lineOne: "Estão para",
                    lineTwo: "vencer",
                    lineThree: nil,
                    isCompact: isCompact,
                    isVeryCompact: isVeryCompact
                )

                summaryDivider(isVeryCompact: isVeryCompact)

                VStack(spacing: 3) {
                    Text(AppStrings.localized(impactLevel.titleKey))
                        .font(AppTheme.schoolbell(isVeryCompact ? 15 : (isCompact ? 17 : 22)))
                        .foregroundStyle(impactLevel.tint)
                        .minimumScaleFactor(0.58)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text("Impacto no caos")
                        .font(AppTheme.schoolbell(isVeryCompact ? 11 : (isCompact ? 12 : 16)))
                        .foregroundStyle(AppTheme.primaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(isVeryCompact ? 11 : (isCompact ? 13 : 16))
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.primaryChaos.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: Color.white.opacity(0.35), radius: 18, x: 0, y: 6)
    }

    private func summaryDivider(isVeryCompact: Bool) -> some View {
        Rectangle()
            .fill(AppTheme.primaryChaos.opacity(0.12))
            .frame(width: 1, height: isVeryCompact ? 74 : 82)
    }

    private func summaryMetric(
        value: String,
        tint: Color,
        lineOne: String,
        lineTwo: String,
        lineThree: String? = nil,
        isCompact: Bool,
        isVeryCompact: Bool
    ) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppTheme.schoolbell(isVeryCompact ? 22 : (isCompact ? 25 : 31)))
                .foregroundStyle(tint)

            if !lineOne.isEmpty {
                Text(lineOne)
                    .font(AppTheme.schoolbell(isVeryCompact ? 10 : (isCompact ? 11 : 15)))
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if !lineTwo.isEmpty {
                Text(lineTwo)
                    .font(AppTheme.schoolbell(isVeryCompact ? 10 : (isCompact ? 11 : 15)))
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if let lineThree {
                Text(lineThree)
                    .font(AppTheme.schoolbell(isVeryCompact ? 10 : (isCompact ? 11 : 15)))
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func filterRow(isCompact: Bool, isVeryCompact: Bool) -> some View {
        HStack(spacing: isVeryCompact ? 10 : (isCompact ? 12 : 14)) {
            ForEach(DeadlineFilter.allCases) { filter in
                let isSelected = selectedFilter == filter

                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.title)
                        .font(AppTheme.schoolbell(isVeryCompact ? 8 : (isCompact ? 9 : 13)))
                        .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, isVeryCompact ? 3 : 5)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: isVeryCompact ? 36 : (isCompact ? 38 : 42))
                        .background(
                            RoundedRectangle(cornerRadius: isVeryCompact ? 15 : (isCompact ? 16 : 18), style: .continuous)
                                .fill(isSelected ? AppTheme.primaryChaos : Color.white.opacity(0.76))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: isVeryCompact ? 15 : (isCompact ? 16 : 18), style: .continuous)
                                .stroke(isSelected ? AppTheme.primaryChaos : AppTheme.primaryChaos.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: isSelected ? AppTheme.primaryChaos.opacity(0.08) : Color.clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tasksSection(isCompact: Bool, isVeryCompact: Bool) -> some View {
        VStack(spacing: isVeryCompact ? 10 : (isCompact ? 12 : 14)) {
            if filteredTasks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nenhuma deadline aqui")
                        .font(AppTheme.schoolbell(isCompact ? 22 : 24))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(AppStrings.localized("tasks.empty.body"))
                        .font(AppTheme.schoolbell(isCompact ? 14 : 16))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .softCard()
            } else {
                ForEach(filteredTasks) { task in
                    deadlineCard(task, isCompact: isCompact, isVeryCompact: isVeryCompact)
                }
            }
        }
    }

    private func deadlineCard(_ task: TaskItem, isCompact: Bool, isVeryCompact: Bool) -> some View {
        let tone = tone(for: task)
        let progress = min(max(task.progress, 0), 1)
        let sessionsProgressText = AppStrings.sessionsValue(
            completed: task.completedSessions,
            total: max(task.tasksQuantity, 1)
        )
        let difficultyValue = "\(task.perceivedDifficulty)"
        let difficultyText = difficultyLabel(for: task)
        let dateLabel = deadlineDateLabel(for: task)
        let cardHeight = isVeryCompact ? 116.0 : 122.0
        let dateWidth = isVeryCompact ? 88.0 : 94.0

        return HStack(alignment: .center, spacing: isVeryCompact ? 10 : 14) {
            deadlineDateColumn(
                dateLabel: dateLabel,
                difficultyValue: difficultyValue,
                tone: tone,
                isVeryCompact: isVeryCompact
            )
            .frame(width: dateWidth)

            Image("DeadlineCardDivider")
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(Color.black.opacity(0.16))
                .frame(width: 1, height: cardHeight - 26)

            deadlineInfoColumn(
                title: task.title,
                difficultyText: difficultyText,
                progress: progress,
                sessionsProgressText: sessionsProgressText,
                tone: tone,
                isVeryCompact: isVeryCompact
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(.horizontal, isVeryCompact ? 14 : 16)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight)
        .background(deadlineCardBackground(tone: tone))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: tone.opacity(0.06), radius: 12, x: 0, y: 5)
        .contentShape(Rectangle())
        .onTapGesture {
            editorRoute = .edit(task)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation(.snappy) {
                    TaskManager(modelContext: modelContext).deleteTask(task)
                }
            } label: {
                Label("Apagar", systemImage: "trash")
            }
        }
    }

    private func deadlineDateColumn(
        dateLabel: String,
        difficultyValue: String,
        tone: Color,
        isVeryCompact: Bool
    ) -> some View {
        VStack(spacing: isVeryCompact ? 7 : 8) {
            Text(verbatim: dateLabel)
                .font(AppTheme.schoolbell(isVeryCompact ? 20 : 24))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: 4) {
                Text("Dif.")
                    .font(AppTheme.schoolbell(isVeryCompact ? 10 : 12))
                    .foregroundStyle(AppTheme.secondaryText)

                Text(verbatim: difficultyValue)
                    .font(AppTheme.schoolbell(isVeryCompact ? 14 : 16))
                    .foregroundStyle(tone)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    private func deadlineInfoColumn(
        title: String,
        difficultyText: String,
        progress: Double,
        sessionsProgressText: String,
        tone: Color,
        isVeryCompact: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: isVeryCompact ? 6 : 7) {
            Text(verbatim: title)
                .font(AppTheme.schoolbell(isVeryCompact ? 14 : 17))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(verbatim: difficultyText)
                .font(AppTheme.schoolbell(isVeryCompact ? 10 : 12))
                .foregroundStyle(tone)
                .lineLimit(1)

            deadlineProgressRow(
                progress: progress,
                sessionsProgressText: sessionsProgressText,
                tone: tone,
                isVeryCompact: isVeryCompact
            )
            .padding(.top, 2)
            .animation(.snappy, value: progress)
        }
    }

    private func deadlineProgressRow(
        progress: Double,
        sessionsProgressText: String,
        tone: Color,
        isVeryCompact: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            GeometryReader { progressProxy in
                let filledWidth = max(progressProxy.size.width * progress, progress > 0 ? 18 : 0)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.track.opacity(0.95))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tone.opacity(0.82), tone.opacity(0.66)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: filledWidth)
                }
            }
            .frame(height: 7)

            Text(verbatim: sessionsProgressText)
                .font(AppTheme.schoolbell(isVeryCompact ? 10 : 12))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private func deadlineCardBackground(tone: Color) -> some View {
        ZStack {
            Image("DeadlineCardBackground")
                .resizable()
                .scaledToFill()

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tone.opacity(0.08))
                .blendMode(.multiply)
        }
    }

    private func legendOverlay(isCompact: Bool, isVeryCompact: Bool) -> some View {
        ZStack {
            AppTheme.background.opacity(0.94)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowingLegend = false
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Legenda")
                        .font(AppTheme.schoolbell(isVeryCompact ? 20 : (isCompact ? 22 : 24)))
                        .foregroundStyle(AppTheme.primaryText)

                    Spacer()

                    Button {
                        isShowingLegend = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryChaos)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.82)))
                    }
                    .buttonStyle(.plain)
                }

                legendRow(color: AppTheme.supportGreen, title: "Baixa", message: "Deadline mais calma.", isCompact: isCompact, isVeryCompact: isVeryCompact)
                legendRow(color: Color(red: 0.88, green: 0.72, blue: 0.21), title: "Média", message: "Pede atenção.", isCompact: isCompact, isVeryCompact: isVeryCompact)
                legendRow(color: AppTheme.primaryChaos, title: "Alta", message: "Impacto maior no caos.", isCompact: isCompact, isVeryCompact: isVeryCompact)
                legendRow(color: AppTheme.critical, title: "Crítica", message: "Muito apertada.", isCompact: isCompact, isVeryCompact: isVeryCompact)
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.paper.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppTheme.primaryChaos.opacity(0.28), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 28)
        }
    }

    private func legendRow(color: Color, title: String, message: String, isCompact: Bool, isVeryCompact: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.schoolbell(isVeryCompact ? 16 : (isCompact ? 18 : 20)))
                    .foregroundStyle(AppTheme.primaryText)

                Text(message)
                    .font(AppTheme.schoolbell(isVeryCompact ? 13 : (isCompact ? 14 : 16)))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private func deadlineDateLabel(for task: TaskItem) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("ddMM")
        return formatter.string(from: task.deadlineDate)
    }

    private func tone(for task: TaskItem) -> Color {
        switch task.perceivedDifficulty {
        case 0...30:
            return AppTheme.supportGreen
        case 31...60:
            return Color(red: 0.88, green: 0.72, blue: 0.21)
        case 61...80:
            return AppTheme.primaryChaos
        default:
            return AppTheme.critical
        }
    }

    private func difficultyLabel(for task: TaskItem) -> String {
        switch task.perceivedDifficulty {
        case 0...30:
            return "Baixa"
        case 31...60:
            return "Média"
        case 61...80:
            return "Alta"
        default:
            return "Crítica"
        }
    }
}

private enum DeadlineFilter: String, CaseIterable, Identifiable {
    case all
    case thisWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Todas"
        case .thisWeek:
            return "Esta semana"
        }
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
