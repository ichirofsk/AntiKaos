import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query(sort: \TaskItem.updatedAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \HistoryEntry.date, order: .reverse) private var historyEntries: [HistoryEntry]

    private var completedTasksCount: Int {
        tasks.filter(\.isCompleted).count
    }

    private var averageWeeklyChaos: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let recentEntries = historyEntries.filter { $0.date >= weekAgo }

        if recentEntries.isEmpty {
            return ChaosCalculator.overallChaos(for: tasks)
        }

        let total = recentEntries.reduce(0) { $0 + $1.chaosValue }
        return Int((Double(total) / Double(recentEntries.count)).rounded())
    }

    private var completedSessionsCount: Int {
        historyEntries.filter { $0.type == .sessionCompleted }.count
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    statsSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle(AppStrings.localized("profile.title"))
        .navigationBarTitleDisplayMode(.large)
    }

    private var statsSection: some View {
        VStack(spacing: 14) {
            statCard(
                title: AppStrings.localized("profile.stats.completedTasks"),
                value: AppStrings.integerValue(completedTasksCount),
                tint: AppTheme.supportGreen
            )

            statCard(
                title: AppStrings.localized("profile.stats.averageChaos"),
                value: AppStrings.scoreCompact(averageWeeklyChaos),
                tint: ChaosLevel(value: averageWeeklyChaos).tint
            )

            statCard(
                title: AppStrings.localized("profile.stats.sessionsDone"),
                value: AppStrings.integerValue(completedSessionsCount),
                tint: AppTheme.primaryChaos
            )
        }
    }

    private func statCard(title: String, value: String, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)

                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer()

            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .stroke(tint.opacity(0.3), lineWidth: 1)
                }
        }
        .softCard()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppStrings.localized("history.title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)

            if historyEntries.isEmpty {
                Text(AppStrings.localized("history.empty"))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .softCard()
            } else {
                ForEach(historyEntries.prefix(8)) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: iconName(for: entry.type))
                            .foregroundStyle(color(for: entry.type))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.message)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.primaryText)

                            Text(AppStrings.historyDate(entry.date))
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer()

                        Text(AppStrings.scoreCompact(entry.chaosValue))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ChaosLevel(value: entry.chaosValue).tint)
                    }
                    .softCard()
                }
            }
        }
    }

    private func iconName(for type: HistoryEntryType) -> String {
        switch type {
        case .taskCreated:
            return "plus.circle.fill"
        case .taskEdited:
            return "square.and.pencil"
        case .sessionCompleted:
            return "checkmark.circle"
        case .taskCompleted:
            return "checkmark.seal.fill"
        }
    }

    private func color(for type: HistoryEntryType) -> Color {
        switch type {
        case .taskCreated:
            return AppTheme.primaryChaos
        case .taskEdited:
            return AppTheme.primaryText
        case .sessionCompleted:
            return AppTheme.supportGreen
        case .taskCompleted:
            return AppTheme.critical
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .modelContainer(TaskManager.previewContainer)
    }
}
