import SwiftUI
import SwiftData

struct PerformanceAnalyticsView: View {
    @Query(sort: \HistoryEntry.date, order: .reverse) private var historyEntries: [HistoryEntry]
    @Query(sort: \TaskItem.updatedAt, order: .reverse) private var tasks: [TaskItem]

    private var weeklyEntries: [HistoryEntry] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: .now) ?? .now
        return historyEntries.filter { $0.date >= calendar.startOfDay(for: weekAgo) }
    }

    private var weeklyChaosAverage: Int {
        guard !weeklyEntries.isEmpty else {
            return ChaosCalculator.overallChaos(for: tasks)
        }

        let total = weeklyEntries.reduce(0) { $0 + $1.chaosValue }
        return Int((Double(total) / Double(weeklyEntries.count)).rounded())
    }

    private var completedTasksCount: Int {
        weeklyEntries.filter { $0.type == .taskCompleted }.count
    }

    private var completedSessionsCount: Int {
        weeklyEntries.filter { $0.type == .sessionCompleted }.count
    }

    private var editedTasksCount: Int {
        weeklyEntries.filter { $0.type == .taskEdited }.count
    }

    private var chartPoints: [AnalyticsChartPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.setLocalizedDateFormatFromTemplate("EE")

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -6 + offset, to: .now) else { return nil }
            let start = calendar.startOfDay(for: day)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let entries = weeklyEntries.filter { $0.date >= start && $0.date < end }
            let chaos = entries.isEmpty ? 0 : Int((Double(entries.reduce(0) { $0 + $1.chaosValue }) / Double(entries.count)).rounded())

            return AnalyticsChartPoint(
                label: formatter.string(from: day).capitalized,
                value: chaos,
                tint: ChaosLevel(value: chaos == 0 ? weeklyChaosAverage : chaos).tint
            )
        }
    }

    private var consistencyRate: Int {
        let activeDays = chartPoints.filter { $0.value > 0 }.count
        return Int((Double(activeDays) / 7.0 * 100.0).rounded())
    }

    private var premiumTeaser: String {
        "Prévia premium"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                heroCard
                chartCard
                insightsCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Análise")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Análise do desempenho")
                .font(AppTheme.schoolbell(30))
                .foregroundStyle(AppTheme.primaryText)

            Text("Uma prévia de como a versão paga pode mostrar sua evolução, consistência e impacto na sobrecarga.")
                .font(AppTheme.schoolbell(16))
                .foregroundStyle(AppTheme.secondaryText)

            Text(premiumTeaser)
                .font(AppTheme.schoolbell(14))
                .foregroundStyle(AppTheme.primaryChaos)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppTheme.primaryChaos.opacity(0.12))
                )
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resumo da semana")
                .font(AppTheme.schoolbell(22))
                .foregroundStyle(AppTheme.primaryText)

            HStack(spacing: 0) {
                analyticsMetric(
                    title: "Sobrecarga média",
                    value: "\(weeklyChaosAverage)/100",
                    tint: ChaosLevel(value: weeklyChaosAverage).tint
                )

                divider

                analyticsMetric(
                    title: "Sessões",
                    value: "\(completedSessionsCount)",
                    tint: AppTheme.primaryChaos
                )

                divider

                analyticsMetric(
                    title: "Concluídas",
                    value: "\(completedTasksCount)",
                    tint: AppTheme.supportGreen
                )
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Evolução da sobrecarga")
                    .font(AppTheme.schoolbell(22))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Text("\(consistencyRate)% consistência")
                    .font(AppTheme.schoolbell(14))
                    .foregroundStyle(AppTheme.primaryChaos)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(chartPoints) { point in
                    VStack(spacing: 8) {
                        Text(point.value == 0 ? "—" : "\(point.value)")
                            .font(AppTheme.schoolbell(12))
                            .foregroundStyle(point.tint)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [point.tint.opacity(0.85), point.tint.opacity(0.45)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(CGFloat(point.value) * 1.2, 12))

                        Text(point.label)
                            .font(AppTheme.schoolbell(12))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 160, alignment: .bottom)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("O que você veria aqui")
                .font(AppTheme.schoolbell(22))
                .foregroundStyle(AppTheme.primaryText)

            insightRow(
                title: "Picos de sobrecarga",
                value: AppStrings.localized(ChaosLevel(value: weeklyChaosAverage).titleKey),
                tint: ChaosLevel(value: weeklyChaosAverage).tint
            )

            insightRow(
                title: "Sessões realizadas",
                value: "\(completedSessionsCount) na semana",
                tint: AppTheme.primaryChaos
            )

            insightRow(
                title: "Mudanças no plano",
                value: "\(editedTasksCount) ajustes feitos",
                tint: AppTheme.supportGreen
            )
        }
        .padding(18)
        .background(cardBackground)
    }

    private func analyticsMetric(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(AppTheme.schoolbell(24))
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(AppTheme.schoolbell(14))
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private func insightRow(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)

            Text(title)
                .font(AppTheme.schoolbell(16))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            Text(value)
                .font(AppTheme.schoolbell(16))
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.primaryText.opacity(0.08))
            .frame(width: 1, height: 62)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.primaryChaos.opacity(0.16), lineWidth: 1)
            )
    }
}

private struct AnalyticsChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
    let tint: Color
}
