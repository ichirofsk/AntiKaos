import SwiftUI

struct TaskCard: View {
    let task: TaskItem
    let canCompleteSession: Bool
    let overdueTaskCount: Int
    let nextActivityDate: Date?
    let onCompleteSession: () -> Void
    let onCompleteTask: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var didTriggerSessionAnimation = false
    @State private var didTriggerTaskAnimation = false
    @State private var isShowingDeleteActions = false

    init(
        task: TaskItem,
        canCompleteSession: Bool = true,
        overdueTaskCount: Int = 0,
        nextActivityDate: Date? = nil,
        onCompleteSession: @escaping () -> Void,
        onCompleteTask: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.task = task
        self.canCompleteSession = canCompleteSession
        self.overdueTaskCount = overdueTaskCount
        self.nextActivityDate = nextActivityDate
        self.onCompleteSession = onCompleteSession
        self.onCompleteTask = onCompleteTask
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.secondarySurface)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text("\(task.perceivedDifficulty)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .contentTransition(.numericText(value: Double(task.perceivedDifficulty)))
                    }

                Text(AppStrings.localized("task.card.difficulty"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.primaryText)

                        Text(AppStrings.deadlineRelativeString(for: task.deadlineDate))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        if task.isPastDeadline {
                            deadlineOutcomeControls
                        } else if !task.isCompleted {
                            activeDeleteButton
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(AppStrings.sessionsValue(completed: task.completedSessions, total: task.tasksQuantity))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Text(AppStrings.tasksQuantity(task.tasksQuantity))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    HStack {
                        Spacer()

                        Text(delayStatusLabel)
                            .font(.caption)
                            .foregroundStyle(overdueTaskCount == 0 ? AppTheme.supportGreen : AppTheme.critical)
                    }

                    ProgressView(value: task.progress)
                        .progressViewStyle(.linear)
                        .tint(task.isCompleted ? AppTheme.supportGreen : task.chaosLevel.tint)
                }

                HStack(spacing: 10) {
                    if !task.isPastDeadline && !task.isCompleted && canCompleteSession {
                        Button {
                            didTriggerSessionAnimation.toggle()
                            onCompleteSession()
                        } label: {
                            Text(AppStrings.localized("task.card.confirmActivity"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.supportGreen)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(AppStrings.localized("task.card.completeSession"))
                        .symbolEffect(.bounce, value: didTriggerSessionAnimation)
                    } else if !task.isPastDeadline && !task.isCompleted {
                        Text(nextActivityLabel)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
        }
        .softCard()
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .confirmationDialog(
            AppStrings.localized("task.card.deletePrompt"),
            isPresented: $isShowingDeleteActions,
            titleVisibility: .visible
        ) {
            Button(AppStrings.localized("task.card.edit")) {
                onEdit()
            }

            Button(AppStrings.localized("task.card.delete"), role: .destructive) {
                onDelete()
            }

            Button(AppStrings.localized("common.cancel"), role: .cancel) {}
        }
    }

    private var deadlineOutcomeControls: some View {
        HStack(spacing: 8) {
            Button {
                guard !task.isCompleted else { return }
                didTriggerTaskAnimation.toggle()
                onCompleteTask()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.seal.fill" : "checkmark.seal")
                    .font(.title3)
                    .foregroundStyle(AppTheme.supportGreen)
                    .symbolEffect(.bounce, value: didTriggerTaskAnimation)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.localized("task.card.completeTask"))

            Button {
                isShowingDeleteActions = true
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.title3)
                    .foregroundStyle(AppTheme.critical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.localized("task.card.delete"))
        }
    }

    private var activeDeleteButton: some View {
        Button {
            isShowingDeleteActions = true
        } label: {
            Image(systemName: "xmark.circle")
                .font(.title3)
                .foregroundStyle(AppTheme.critical)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppStrings.localized("task.card.delete"))
    }

    private var delayStatusLabel: String {
        guard overdueTaskCount > 0 else {
            return AppStrings.localized("task.delay.none")
        }

        return AppStrings.overdueTasks(overdueTaskCount)
    }

    private var nextActivityLabel: String {
        guard let nextActivityDate else {
            return AppStrings.localized("task.nextActivity.none")
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let startOfActivityDay = calendar.startOfDay(for: nextActivityDate)
        let dayCount = max(calendar.dateComponents([.day], from: startOfToday, to: startOfActivityDay).day ?? 0, 0)

        if dayCount == 1 {
            return AppStrings.localized("task.nextActivity.tomorrow")
        }

        return AppStrings.nextActivity(days: dayCount)
    }
}
