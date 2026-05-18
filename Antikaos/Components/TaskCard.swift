import SwiftUI

struct TaskCard: View {
    let task: TaskItem
    let onCompleteSession: () -> Void
    let onEdit: () -> Void

    @State private var didTriggerSessionAnimation = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.secondarySurface)
                    .frame(width: 56, height: 56)
                    .overlay {
                        VStack(spacing: 2) {
                            Text("\(task.perceivedDifficulty)")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                                .contentTransition(.numericText(value: Double(task.perceivedDifficulty)))

                            Text(AppStrings.localized("task.difficulty.short"))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }

                Text(AppStrings.localized(task.chaosLevel.titleKey))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(task.chaosLevel.tint)
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

                    Text(AppStrings.scoreCompact(task.chaosScore))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(task.chaosLevel.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(task.chaosLevel.tint.opacity(0.12), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(AppStrings.sessionsValue(completed: task.completedSessions, total: task.totalSessions))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Text(task.isCompleted ? AppStrings.localized("task.status.completed") : AppStrings.localized("task.status.active"))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    ProgressView(value: task.progress)
                        .progressViewStyle(.linear)
                        .tint(task.isCompleted ? AppTheme.supportGreen : task.chaosLevel.tint)
                }

                HStack(spacing: 10) {
                    Button {
                        didTriggerSessionAnimation.toggle()
                        onCompleteSession()
                    } label: {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(task.isCompleted ? AppTheme.supportGreen : AppTheme.primaryChaos)
                            .symbolEffect(.bounce, value: didTriggerSessionAnimation)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppStrings.localized("task.card.completeSession"))
                    .disabled(task.isCompleted)

                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppStrings.localized("task.card.edit"))
                }
            }
        }
        .softCard()
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}
