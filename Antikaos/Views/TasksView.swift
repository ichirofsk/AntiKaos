import SwiftUI
import SwiftData
import StoreKit
import UIKit

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premiumAccessManager: PremiumAccessManager
    @EnvironmentObject private var premiumFlowManager: PremiumFlowManager
    @Query(sort: \TaskItem.deadlineDate, order: .forward) private var tasks: [TaskItem]
    @Query(sort: \GeneratedTaskItem.scheduledDate, order: .forward) private var generatedTasks: [GeneratedTaskItem]

    @State private var editorRoute: TaskEditorRoute?
    @State private var selectedFilter: DeadlineFilter = .all
    @State private var isShowingLegend = false
    @State private var premiumPaywallContext: PremiumPaywallContext?
    @State private var isShowingWidgetInstructions = false
    @State private var isOverdueTasksExpanded = false
    @State private var detailTask: TaskItem?

    private let freeDeadlineLimit = 3

    private var pendingTasks: [TaskItem] {
        tasks
            .filter { !$0.isCompleted && !$0.isPastDeadline && $0.remainingSessions > 0 }
            .sorted { lhs, rhs in
                let lhsWeight = DeadlinePriority.weight(for: lhs)
                let rhsWeight = DeadlinePriority.weight(for: rhs)
                if lhsWeight != rhsWeight {
                    return lhsWeight > rhsWeight
                }

                if lhs.deadlineDate != rhs.deadlineDate {
                    return lhs.deadlineDate < rhs.deadlineDate
                }

                if lhs.perceivedDifficulty != rhs.perceivedDifficulty {
                    return lhs.perceivedDifficulty > rhs.perceivedDifficulty
                }

                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var filteredTasks: [TaskItem] {
        switch selectedFilter {
        case .all:
            return pendingTasks
        case .onTrack:
            return pendingTasks.filter { isActiveDeadline($0) && !isDelayed($0) }
        case .delayed:
            return pendingTasks.filter { isActiveDeadline($0) && isDelayed($0) }
        case .future:
            return pendingTasks.filter { !isActiveDeadline($0) }
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

    private var overdueGeneratedTasks: [GeneratedTaskItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let activeTaskIDs = Set(ChaosCalculator.activeTasksForOverload(from: pendingTasks).map(\.id))

        return generatedTasks
            .filter { generatedTask in
                activeTaskIDs.contains(generatedTask.parentTaskID)
                    && !generatedTask.isCompleted
                    && !generatedTask.isDelayDismissed
                    && calendar.startOfDay(for: generatedTask.scheduledDate) < today
            }
            .sorted { lhs, rhs in
                if lhs.scheduledDate != rhs.scheduledDate {
                    return lhs.scheduledDate > rhs.scheduledDate
                }

                return lhs.createdAt > rhs.createdAt
            }
    }

    private var impactLevel: ChaosLevel {
        ChaosLevel(value: ChaosCalculator.overallChaos(for: pendingTasks))
    }

    private var canCreateDeadline: Bool {
        premiumAccessManager.hasUnlimitedDeadlines || tasks.count < freeDeadlineLimit
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
                        overdueTasksCard(isCompact: isCompact, isVeryCompact: isVeryCompact)
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
            EditTaskView(task: route.task, onDelete: route.task == nil ? nil : {
                if let task = route.task {
                    TaskManager(modelContext: modelContext).deleteTask(task)
                }
                editorRoute = nil
            }) { formData in
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
        .fullScreenCover(item: $detailTask) { task in
            deadlineDetailSheet(task: task, isCompact: false, isVeryCompact: false)
        }
        .sheet(item: $premiumPaywallContext) { context in
            PremiumPaywallView(context: context)
                .environmentObject(premiumAccessManager)
                .presentationDetents([.medium, .large])
        }
        .alert("Como adicionar o widget", isPresented: $isShowingWidgetInstructions) {
            Button("Entendi", role: .cancel) { }
        } message: {
            Text("Na tela inicial do iPhone, toque e segure em uma área vazia, toque em +, procure por Antikaos e escolha o widget.")
        }
        .onAppear {
            if let requestedContext = premiumFlowManager.consume() {
                premiumPaywallContext = requestedContext
            }
        }
        .onChange(of: premiumFlowManager.requestedContext?.id) { _, _ in
            if let requestedContext = premiumFlowManager.consume() {
                premiumPaywallContext = requestedContext
            }
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
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.impact(.light)
                    if canCreateDeadline {
                        editorRoute = .create
                    } else {
                        premiumPaywallContext = .deadlines(limit: freeDeadlineLimit)
                    }
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
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    HapticManager.impact(.light)
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

                    Text("Impacto na sobrecarga")
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
                .fill(AppTheme.paper.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.primaryChaos.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: AppTheme.primaryChaos.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func overdueTasksCard(isCompact: Bool, isVeryCompact: Bool) -> some View {
        let overdueTasks = overdueGeneratedTasks
        let title = overdueTasks.isEmpty ? "Nenhuma task em atraso" : "\(overdueTasks.count) tasks em atraso"
        let tone = AppTheme.supportGreen

        return VStack(alignment: .leading, spacing: isVeryCompact ? 9 : 12) {
            Button {
                HapticManager.selection()
                withAnimation(.snappy(duration: 0.24)) {
                    isOverdueTasksExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tasks atrasadas")
                            .font(AppTheme.schoolbell(isVeryCompact ? 18 : (isCompact ? 20 : 22)))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)

                        if isOverdueTasksExpanded {
                            Text(title)
                                .font(AppTheme.schoolbell(isVeryCompact ? 13 : (isCompact ? 14 : 16)))
                                .foregroundStyle(tone)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                    }

                    Spacer(minLength: 10)

                    Image(systemName: isOverdueTasksExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: isVeryCompact ? 13 : 15, weight: .bold))
                        .foregroundStyle(tone)
                        .frame(width: isVeryCompact ? 30 : 34, height: isVeryCompact ? 30 : 34)
                        .background(Circle().fill(Color.white.opacity(0.74)))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOverdueTasksExpanded {
                if !overdueTasks.isEmpty {
                    VStack(spacing: isVeryCompact ? 8 : 10) {
                        ForEach(overdueTasks) { generatedTask in
                            overdueTaskRow(generatedTask, isCompact: isCompact, isVeryCompact: isVeryCompact)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(isVeryCompact ? 11 : (isCompact ? 13 : 15))
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tone.opacity(0.14),
                            AppTheme.paper.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tone.opacity(0.24), lineWidth: 1)
                )
        )
        .shadow(color: tone.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func overdueTaskRow(_ generatedTask: GeneratedTaskItem, isCompact: Bool, isVeryCompact: Bool) -> some View {
        HStack(alignment: .center, spacing: isVeryCompact ? 8 : 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(generatedTask.title)
                    .font(AppTheme.schoolbell(isVeryCompact ? 13 : (isCompact ? 14 : 16)))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text("\(overdueTaskDateLabel(for: generatedTask.scheduledDate)) · \(parentDeadlineTitle(for: generatedTask))")
                    .font(AppTheme.schoolbell(isVeryCompact ? 10 : 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            Button {
                HapticManager.notify(.success)
                withAnimation(.snappy) {
                    TaskManager(modelContext: modelContext).completeGeneratedTask(id: generatedTask.id)
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: isVeryCompact ? 12 : 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: isVeryCompact ? 30 : 34, height: isVeryCompact ? 30 : 34)
                    .background(Circle().fill(AppTheme.supportGreen))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Marcar task como compensada")

            Button {
                HapticManager.impact(.light)
                withAnimation(.snappy) {
                    generatedTask.isDelayDismissed = true
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: isVeryCompact ? 11 : 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: isVeryCompact ? 30 : 34, height: isVeryCompact ? 30 : 34)
                    .background(Circle().fill(AppTheme.critical))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Descartar task atrasada deste card")
        }
        .padding(.horizontal, isVeryCompact ? 10 : 12)
        .padding(.vertical, isVeryCompact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
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
                    HapticManager.selection()
                    withAnimation(.snappy(duration: 0.22)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.title)
                        .font(AppTheme.schoolbell(isVeryCompact ? 11 : (isCompact ? 12 : 14)))
                        .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, isVeryCompact ? 4 : 6)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: isVeryCompact ? 44 : 46)
                        .background(
                            RoundedRectangle(cornerRadius: isVeryCompact ? 15 : (isCompact ? 16 : 18), style: .continuous)
                                .fill(isSelected ? AppTheme.primaryChaos : Color.white.opacity(0.76))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: isVeryCompact ? 15 : (isCompact ? 16 : 18), style: .continuous)
                                .stroke(isSelected ? AppTheme.primaryChaos : AppTheme.primaryChaos.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: isSelected ? AppTheme.primaryChaos.opacity(0.08) : Color.clear, radius: 8, x: 0, y: 4)
                        .contentShape(RoundedRectangle(cornerRadius: isVeryCompact ? 15 : (isCompact ? 16 : 18), style: .continuous))
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
        let textTone = readableTone(for: task)
        let isActive = isActiveDeadline(task)
        let isDelayed = isActive && isDelayed(task)
        let statusTone = isActive ? delayStatusTone(isDelayed: isDelayed) : futureStatusTone
        let progress = min(max(task.progress, 0), 1)
        let sessionsProgressText = "\(task.completedSessions)/\(max(task.tasksQuantity, 1))"
        let difficultyValue = "Dificuldade \(task.perceivedDifficulty)"
        let difficultyText = difficultyLabel(for: task)
        let dateLabel = deadlineDateLabel(for: task)
        let cardHeight = isActive ? (isVeryCompact ? 138.0 : 148.0) : (isVeryCompact ? 148.0 : 158.0)
        let dateWidth = isVeryCompact ? 96.0 : 106.0
        let horizontalPadding = isVeryCompact ? 14.0 : 16.0
        let columnSpacing = isVeryCompact ? 10.0 : 14.0
        let leftPanelWidth = dateWidth + horizontalPadding + columnSpacing + 0.5

        let cardContent = HStack(alignment: .center, spacing: isVeryCompact ? 10 : 14) {
            HStack(alignment: .center, spacing: columnSpacing) {
                deadlineDateColumn(
                    dateLabel: dateLabel,
                    difficultyValue: difficultyValue,
                    difficultyText: difficultyText,
                    tone: textTone,
                    isVeryCompact: isVeryCompact
                )
                .frame(width: dateWidth)
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.impact(.light)
                    detailTask = task
                }

                deadlineInfoColumn(
                    title: task.title,
                    progress: progress,
                    sessionsProgressText: sessionsProgressText,
                    activationText: isActive ? nil : activationText(for: task),
                    isDelayed: isDelayed,
                    isActive: isActive,
                    statusTone: statusTone,
                    tone: tone,
                    textTone: textTone,
                    isVeryCompact: isVeryCompact,
                    onDetails: {
                        HapticManager.impact(.light)
                        detailTask = task
                    },
                    onEdit: {
                        HapticManager.impact(.light)
                        editorRoute = .edit(task)
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, columnSpacing + 1)
                .layoutPriority(1)
            }
            .padding(.horizontal, horizontalPadding)
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight)
        .background(deadlineCardBackground(difficultyTone: tone, statusTone: statusTone, splitWidth: leftPanelWidth))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tone.opacity(0.28), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tone.opacity(0.24))
                .frame(width: 1)
                .padding(.vertical, 0)
                .offset(x: leftPanelWidth)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.impact(.light)
            detailTask = task
        }

        return SwipeToDeadlineActionCard(
            onDelete: {
                delete(task)
            },
            onComplete: {
                TaskManager(modelContext: modelContext).completeSession(for: task)
            }
        ) {
            cardContent
        }
    }

    private func deadlineDateColumn(
        dateLabel: String,
        difficultyValue: String,
        difficultyText: String,
        tone: Color,
        isVeryCompact: Bool
    ) -> some View {
        VStack(spacing: isVeryCompact ? 6 : 7) {
            Text(verbatim: dateLabel)
                .font(AppTheme.schoolbell(isVeryCompact ? 27 : 31))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(verbatim: difficultyValue)
                .font(AppTheme.schoolbell(isVeryCompact ? 12 : 14))
                .foregroundStyle(tone)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(verbatim: difficultyText)
                .font(AppTheme.schoolbell(isVeryCompact ? 16 : 18))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxHeight: .infinity)
    }

    private func deadlineInfoColumn(
        title: String,
        progress: Double,
        sessionsProgressText: String,
        activationText: String?,
        isDelayed: Bool,
        isActive: Bool,
        statusTone: Color,
        tone: Color,
        textTone: Color,
        isVeryCompact: Bool,
        onDetails: @escaping () -> Void,
        onEdit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: isVeryCompact ? 8 : 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: isVeryCompact ? 4 : 5) {
                    Text(verbatim: title)
                        .font(AppTheme.schoolbell(isVeryCompact ? 21 : 24))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    if isActive {
                        deadlineDelayTag(isDelayed: isDelayed, tone: statusTone, isVeryCompact: isVeryCompact)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onDetails)
                .layoutPriority(1)

                Spacer(minLength: 4)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: isVeryCompact ? 13 : 14, weight: .semibold))
                        .foregroundStyle(textTone)
                        .frame(width: isVeryCompact ? 30 : 34, height: isVeryCompact ? 30 : 34)
                        .background(Circle().fill(Color.white.opacity(0.56)))
                        .overlay(Circle().stroke(textTone.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Editar deadline")
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onDetails)

            deadlineProgressRow(
                progress: progress,
                sessionsProgressText: sessionsProgressText,
                tone: textTone,
                isVeryCompact: isVeryCompact
            )
            .animation(.snappy, value: progress)
            .contentShape(Rectangle())
            .onTapGesture(perform: onDetails)

            if let activationText {
                Text(activationText)
                    .font(AppTheme.schoolbell(isVeryCompact ? 13 : 15))
                    .foregroundStyle(statusTone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDetails)
            }
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
                        .fill(Color.white.opacity(0.78))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tone.opacity(0.92), tone.opacity(0.72)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: filledWidth)
                }
            }
            .frame(height: 7)

            Text(verbatim: sessionsProgressText)
                .font(AppTheme.schoolbell(isVeryCompact ? 13 : 15))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private func deadlineCardBackground(difficultyTone: Color, statusTone: Color, splitWidth: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(difficultyTone.opacity(0.16))

            HStack(spacing: 0) {
                Rectangle()
                    .fill(difficultyTone.opacity(0.22))
                    .frame(width: splitWidth)

                Rectangle()
                    .fill(difficultyTone.opacity(0.11))
            }

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(difficultyTone.opacity(0.24), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                legendRow(color: AppTheme.primaryChaos, title: "Alta", message: "Impacto maior na sobrecarga.", isCompact: isCompact, isVeryCompact: isVeryCompact)
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

    private func overdueTaskDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("dd MMM")
        return formatter.string(from: date)
    }

    private func deadlineFullDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("dd MMM yyyy HHmm")
        return formatter.string(from: date)
    }

    private func parentDeadlineTitle(for generatedTask: GeneratedTaskItem) -> String {
        tasks.first(where: { $0.id == generatedTask.parentTaskID })?.title ?? "Deadline"
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

    private func readableTone(for task: TaskItem) -> Color {
        switch task.perceivedDifficulty {
        case 0...30:
            return Color(red: 0.20, green: 0.40, blue: 0.24)
        case 31...60:
            return Color(red: 0.66, green: 0.46, blue: 0.06)
        case 61...80:
            return Color(red: 0.67, green: 0.28, blue: 0.10)
        default:
            return Color(red: 0.55, green: 0.16, blue: 0.12)
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

    private func isDelayed(_ task: TaskItem) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return generatedTasks.contains { generatedTask in
            generatedTask.parentTaskID == task.id
                && !generatedTask.isCompleted
                && calendar.startOfDay(for: generatedTask.scheduledDate) < today
        }
    }

    private func isActiveDeadline(_ task: TaskItem) -> Bool {
        ChaosCalculator.activeTasksForOverload(from: tasks).contains { $0.id == task.id }
    }

    private var futureStatusTone: Color {
        Color(red: 0.38, green: 0.47, blue: 0.58)
    }

    private func activationText(for task: TaskItem) -> String {
        let days = max(daysUntilActivation(for: task), 0)
        return days == 1 ? "Ativa em 1 dia." : "Ativa em \(days) dias."
    }

    private func daysUntilActivation(for task: TaskItem) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let activationDate: Date?

        switch task.dedicationStartMode {
        case .today:
            activationDate = today
        case .tomorrow:
            activationDate = task.dedicationStartDate
                ?? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: task.createdAt))
        case .specificDate:
            activationDate = task.dedicationStartDate
        case .afterDeadline:
            activationDate = tasks.first(where: { $0.id == task.dedicationDependencyTaskID })?.deadlineDate
        }

        guard let activationDate else { return 0 }
        return calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: activationDate)).day ?? 0
    }

    private func delayStatusTone(isDelayed: Bool) -> Color {
        isDelayed ? Color(red: 0.78, green: 0.18, blue: 0.15) : Color(red: 0.24, green: 0.62, blue: 0.36)
    }

    private func deadlineDelayTag(isDelayed: Bool, tone: Color, isVeryCompact: Bool) -> some View {
        Text(isDelayed ? "Em atraso" : "Em dia")
            .font(AppTheme.schoolbell(isVeryCompact ? 14 : 16))
            .foregroundStyle(tone)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }

    private func deadlineDetailSheet(task: TaskItem, isCompact: Bool, isVeryCompact: Bool) -> some View {
        let tone = tone(for: task)
        let textTone = readableTone(for: task)
        let isActive = isActiveDeadline(task)
        let isDelayed = isActive && isDelayed(task)
        let statusTone = isActive ? delayStatusTone(isDelayed: isDelayed) : futureStatusTone
        let taskGeneratedTasks = generatedTasks
            .filter { $0.parentTaskID == task.id }
            .sorted { $0.scheduledDate < $1.scheduledDate }
        let nextGeneratedTask = taskGeneratedTasks.first { !$0.isCompleted }
        let completedGeneratedTasks = taskGeneratedTasks.filter(\.isCompleted).count
        let totalSessions = max(task.tasksQuantity, task.totalSessions, 1)
        let completedSessions = max(task.completedSessions, completedGeneratedTasks)

        return ZStack {
            tone.opacity(0.16)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 10) {
                        Button {
                            detailTask = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(textTone)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.white.opacity(0.64)))
                                .overlay(Circle().stroke(textTone.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Fechar detalhes")

                        Spacer()

                        Button {
                            detailTask = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                editorRoute = .edit(task)
                            }
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(textTone)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.white.opacity(0.64)))
                                .overlay(Circle().stroke(textTone.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Editar deadline")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(AppTheme.schoolbell(isVeryCompact ? 30 : 34))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(3)
                            .minimumScaleFactor(0.72)
                    }

                    VStack(spacing: 10) {
                        detailStatRow(title: "Status", value: isDelayed ? "Em atraso" : "Em dia", tint: statusTone)
                        detailStatRow(title: "Data da deadline", value: deadlineFullDateLabel(for: task.deadlineDate), tint: textTone)
                        detailStatRow(title: "Dificuldade", value: "\(task.perceivedDifficulty) - \(difficultyLabel(for: task))", tint: textTone)
                        detailStatRow(title: "Sessões feitas", value: "\(completedSessions)/\(totalSessions)", tint: textTone)
                        detailStatRow(title: "Sessões restantes", value: "\(max(totalSessions - completedSessions, 0))", tint: textTone)
                        detailStatRow(title: "Sobrecarga", value: "\(task.chaosScore)", tint: statusTone)
                        detailStatRow(title: "Dedicação", value: "\(task.dedicationMinutes) min", tint: textTone)

                        if let nextGeneratedTask {
                            detailStatRow(
                                title: "Próxima atividade",
                                value: overdueTaskDateLabel(for: nextGeneratedTask.scheduledDate),
                                tint: statusTone
                            )
                        }
                    }

                    let notes = task.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notas")
                                .font(AppTheme.schoolbell(18))
                                .foregroundStyle(AppTheme.primaryText)

                            Text(notes)
                                .font(AppTheme.schoolbell(15))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.44))
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func detailStatRow(title: String, value: String, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.schoolbell(15))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer(minLength: 10)

            Text(value)
                .font(AppTheme.schoolbell(18))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.50))
        )
    }

    private func delete(_ task: TaskItem) {
        withAnimation(.snappy) {
            TaskManager(modelContext: modelContext).deleteTask(task)
        }
    }
}

private struct SwipeToDeadlineActionCard<Content: View>: View {
    let onDelete: () -> Void
    let onComplete: () -> Void
    @ViewBuilder let content: Content

    @State private var horizontalOffset: CGFloat = 0

    private let deleteThreshold: CGFloat = 190
    private let completeThreshold: CGFloat = 110

    var body: some View {
        let completeProgress = min(max(horizontalOffset / completeThreshold, 0), 1)
        let deleteProgress = min(max(-horizontalOffset / deleteThreshold, 0), 1)

        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.critical.opacity(0.16 + 0.54 * deleteProgress))
                .overlay(alignment: .trailing) {
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white.opacity(0.46 + 0.54 * deleteProgress))
                        .padding(.trailing, 24)
                }
                .opacity(deleteProgress > 0 ? 1 : 0)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.supportGreen.opacity(0.16 + 0.54 * completeProgress))
                .overlay(alignment: .leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white.opacity(0.46 + 0.54 * completeProgress))

                        Text("Concluir")
                            .font(AppTheme.schoolbell(16))
                            .foregroundStyle(.white.opacity(0.46 + 0.54 * completeProgress))
                    }
                    .padding(.leading, 22)
                }
                .opacity(completeProgress > 0 ? 1 : 0)

            content
                .offset(x: horizontalOffset)
                .gesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .local)
                        .onChanged { value in
                            let horizontal = value.translation.width
                            let vertical = value.translation.height

                            guard abs(horizontal) > abs(vertical) else { return }

                            if horizontal < 0 {
                                horizontalOffset = max(horizontal, -230)
                            } else {
                                horizontalOffset = min(horizontal, 150)
                            }
                        }
                        .onEnded { value in
                            let horizontal = value.translation.width
                            let predictedHorizontal = value.predictedEndTranslation.width
                            let vertical = value.translation.height

                            guard abs(horizontal) > abs(vertical) else {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                                    horizontalOffset = 0
                                }
                                return
                            }

                            if horizontal <= -deleteThreshold || predictedHorizontal <= -deleteThreshold * 1.08 {
                                HapticManager.notify(.warning)
                                withAnimation(.easeIn(duration: 0.16)) {
                                    horizontalOffset = -520
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                    onDelete()
                                }
                            } else if horizontal >= completeThreshold || predictedHorizontal >= completeThreshold * 1.08 {
                                HapticManager.notify(.success)
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                                    horizontalOffset = 128
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                    onComplete()
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                                        horizontalOffset = 0
                                    }
                                }
                            } else {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                                    horizontalOffset = 0
                                }
                            }
                        }
                )
        }
        .contentShape(Rectangle())
    }
}

private enum DeadlineFilter: String, CaseIterable, Identifiable {
    case all
    case onTrack
    case delayed
    case future

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Todos"
        case .onTrack:
            return "Em dia"
        case .delayed:
            return "Em atraso"
        case .future:
            return "Futuras"
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
