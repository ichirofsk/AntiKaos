import SwiftUI

struct TaskCard: View {
    let task: TaskItem
    let canCompleteSession: Bool
    let overdueTaskCount: Int
    let onCompleteSession: () -> Void
    let onCompleteTask: () -> Void
    let onEdit: () -> Void

    @State private var didTriggerSessionAnimation = false
    @State private var didTriggerTaskAnimation = false

    init(
        task: TaskItem,
        canCompleteSession: Bool = true,
        overdueTaskCount: Int = 0,
        onCompleteSession: @escaping () -> Void,
        onCompleteTask: @escaping () -> Void,
        onEdit: @escaping () -> Void
    ) {
        self.task = task
        self.canCompleteSession = canCompleteSession
        self.overdueTaskCount = overdueTaskCount
        self.onCompleteSession = onCompleteSession
        self.onCompleteTask = onCompleteTask
        self.onEdit = onEdit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(deadlineDateLabel)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minWidth: 82, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 0)
                                .fill(statusColor.opacity(0.35))
                        )

                    difficultyView
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(task.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.primaryText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)

                            delayTag
                        }

                        Spacer(minLength: 8)

                        if task.isPastDeadline {
                            deadlineOutcomeControls
                        }
                    }

                    HStack {
                        Spacer(minLength: 8)

                        Text(AppStrings.sessionsValue(completed: task.completedSessions, total: task.tasksQuantity))
                            .font(.title.weight(.bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .contentTransition(.numericText(value: Double(task.completedSessions)))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .tint(statusColor)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)

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
                    }
                }
            }
        }
        .softCard()
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }

    private var difficultyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Circle()
                .fill(AppTheme.secondarySurface)
                .frame(width: 58, height: 58)
                .overlay {
                    Text("\(task.perceivedDifficulty)")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .contentTransition(.numericText(value: Double(task.perceivedDifficulty)))
                }

            Text(AppStrings.localized("task.card.difficulty"))
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var delayTag: some View {
        Text(statusLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(statusColor.opacity(0.18))
            )
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
        }
    }

    private var isDelayed: Bool {
        overdueTaskCount > 0 || (task.isPastDeadline && !task.isCompleted)
    }

    private var statusColor: Color {
        isDelayed ? AppTheme.critical : AppTheme.supportGreen
    }

    private var statusLabel: String {
        isDelayed ? AppStrings.localized("task.status.delayed") : AppStrings.localized("task.status.onTime")
    }

    private var deadlineDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("ddMM")
        return formatter.string(from: task.deadlineDate)
    }
}
