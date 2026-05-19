import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("profile.userName") private var userName = ""
    @Query(sort: \TaskItem.updatedAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \HistoryEntry.date, order: .reverse) private var historyEntries: [HistoryEntry]
    @Query(sort: \modelHorasDisponiveis.updatedAt, order: .reverse) private var availableHoursModels: [modelHorasDisponiveis]
    @State private var isEditingAvailableHours = false
    @State private var isEditingUserName = false
    @State private var draftUserName = ""

    private var completedTasksCount: Int {
        historyEntries.filter { $0.type == .taskCompleted }.count
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

    private var profileHeaderTitle: String {
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? AppStrings.localized("profile.title") : trimmedName
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(profileHeaderTitle)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 4)

                    statsSection
                    userNameSection
                    availableHoursSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            createAvailableHoursModelIfNeeded()
            resetDraftUserName()
        }
    }

    private var userNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Nome")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.black)

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        if isEditingUserName {
                            resetDraftUserName()
                            isEditingUserName = false
                        } else {
                            resetDraftUserName()
                            isEditingUserName = true
                        }
                    }
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isEditingUserName ? Color.white : AppTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isEditingUserName ? AppTheme.primaryChaos : Color.white.opacity(0.72))
                                .overlay {
                                    Circle()
                                        .stroke(AppTheme.primaryText.opacity(0.12), lineWidth: 1)
                                }
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEditingUserName ? "Cancelar edição do nome" : "Editar nome")
            }

            if isEditingUserName {
                HStack(spacing: 10) {
                    TextField("Nome", text: $draftUserName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button("Salvar") {
                        saveDraftUserName()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(height: 42)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(trimmedDraftUserName.isEmpty ? AppTheme.secondaryText.opacity(0.35) : AppTheme.primaryChaos)
                    )
                    .disabled(trimmedDraftUserName.isEmpty)
                }
            } else {
                Text(userName.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .softCard()
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
                    .foregroundStyle(Color.black)

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

    @ViewBuilder
    private var availableHoursSection: some View {
        if let availableHours = availableHoursModels.first {
            AvailableHoursCard(
                availableHours: availableHours,
                isEditing: $isEditingAvailableHours,
                onChange: saveAvailableHours
            )
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppStrings.localized("history.title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.black)

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

    private func createAvailableHoursModelIfNeeded() {
        guard availableHoursModels.isEmpty else { return }

        modelContext.insert(modelHorasDisponiveis())
        saveAvailableHours()
    }

    private func saveAvailableHours() {
        TaskManager(modelContext: modelContext).rebalanceGeneratedTasks()
    }

    private var trimmedDraftUserName: String {
        draftUserName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resetDraftUserName() {
        draftUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveDraftUserName() {
        guard !trimmedDraftUserName.isEmpty else { return }

        userName = trimmedDraftUserName
        draftUserName = trimmedDraftUserName

        withAnimation(.snappy(duration: 0.22)) {
            isEditingUserName = false
        }
    }
}

struct AvailableHoursCard: View {
    @Bindable var availableHours: modelHorasDisponiveis
    @Binding var isEditing: Bool
    let onChange: () -> Void
    var showsHeader = true
    var allowsEditingToggle = true
    @State private var draftHours: [AvailableWeekday: Int] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                header
            }

            GeometryReader { proxy in
                let metrics = AvailableHoursLayoutMetrics(width: proxy.size.width)

                HStack(alignment: .top, spacing: metrics.columnSpacing) {
                    ForEach(AvailableWeekday.allCases) { day in
                        VStack(spacing: metrics.daySpacing) {
                            Text(day.shortTitle)
                                .font(.system(size: metrics.labelFontSize, weight: .medium))
                                .foregroundStyle(Color.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(width: metrics.dayColumnWidth)

                            AvailableHoursSlider(
                                value: displayedHours(for: day),
                                isEditing: isEditing,
                                trackHeight: metrics.trackHeight,
                                fillWidth: metrics.sliderWidth
                            ) { value in
                                draftHours[day] = min(max(value, 0), 24)
                            }
                        }
                        .frame(width: metrics.dayColumnWidth)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: AvailableHoursLayoutMetrics.panelHeight)
            .padding(.horizontal, 10)
            .padding(.top, 18)
            .padding(.bottom, 10)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(alignment: .topTrailing) {
                if !isEditing {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .allowsHitTesting(false)
                }
            }

            if !showsHeader {
                HStack {
                    Spacer()
                    saveButton
                }
            }
        }
        .onAppear(perform: resetDraftHours)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Meu tempo disponível:")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.black)

            Spacer()

            saveButton

            if allowsEditingToggle {
                editButton
            }
        }
    }

    var saveButton: some View {
        Group {
            if isEditing {
                Button {
                    applyDraftHours()
                    onChange()

                    withAnimation(.snappy(duration: 0.22)) {
                        isEditing = false
                    }
                } label: {
                    Text("Salvar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(AppTheme.primaryChaos)
                        )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .accessibilityLabel("Salvar tempo disponível")
            }
        }
    }

    private var editButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                if isEditing {
                    resetDraftHours()
                    isEditing = false
                } else {
                    resetDraftHours()
                    isEditing = true
                }
            }
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEditing ? Color.white : AppTheme.primaryText)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isEditing ? AppTheme.primaryChaos : Color.white.opacity(0.72))
                        .overlay {
                            Circle()
                                .stroke(AppTheme.primaryText.opacity(0.12), lineWidth: 1)
                        }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isEditing ? "Concluir edição do tempo disponível" : "Editar tempo disponível")
    }

    private func displayedHours(for day: AvailableWeekday) -> Int {
        if isEditing {
            return draftHours[day] ?? availableHours.horas(for: day)
        }

        return availableHours.horas(for: day)
    }

    private func resetDraftHours() {
        draftHours = Dictionary(
            uniqueKeysWithValues: AvailableWeekday.allCases.map { day in
                (day, availableHours.horas(for: day))
            }
        )
    }

    private func applyDraftHours() {
        for day in AvailableWeekday.allCases {
            availableHours.setHoras(draftHours[day] ?? availableHours.horas(for: day), for: day)
        }
    }
}

private struct AvailableHoursLayoutMetrics {
    static let panelHeight: CGFloat = 218

    let width: CGFloat

    var columnSpacing: CGFloat { width < 360 ? 4 : 7 }
    var daySpacing: CGFloat { width < 360 ? 10 : 12 }
    var labelFontSize: CGFloat { width < 360 ? 16 : 18 }
    var trackHeight: CGFloat { min(178, max(146, width * 0.44)) }

    var dayColumnWidth: CGFloat {
        let gaps = columnSpacing * CGFloat(AvailableWeekday.allCases.count - 1)
        let availableWidth = width - gaps
        return max(28, floor(availableWidth / CGFloat(AvailableWeekday.allCases.count)))
    }

    var sliderWidth: CGFloat {
        min(42, max(28, dayColumnWidth - 4))
    }
}

private struct AvailableHoursSlider: View {
    let value: Int
    let isEditing: Bool
    let trackHeight: CGFloat
    let fillWidth: CGFloat
    let onValueChange: (Int) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.88))
                    .frame(width: 1.4, height: trackHeight)
                    .padding(.bottom, 10)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.supportGreen.opacity(isEditing ? 0.78 : 0.58))
                    .frame(width: fillWidth, height: fillHeight)
                    .overlay(alignment: .center) {
                        Text("\(value)h")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(Color.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .padding(.bottom, 0)
                    .shadow(color: Color.black.opacity(isEditing ? 0.08 : 0), radius: 6, x: 0, y: 3)
            }
            .frame(height: trackHeight + 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEditing else { return }
                        updateValue(from: gesture.location.y)
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Horas disponíveis")
            .accessibilityValue("\(value) horas")
            .accessibilityAdjustableAction { direction in
                guard isEditing else { return }

                switch direction {
                case .increment:
                    onValueChange(value + 1)
                case .decrement:
                    onValueChange(value - 1)
                @unknown default:
                    break
                }
            }
        }
        .opacity(isEditing ? 1 : 0.86)
        .allowsHitTesting(isEditing)
    }

    private var fillHeight: CGFloat {
        max(42, CGFloat(value) / 24 * trackHeight)
    }

    private func updateValue(from locationY: CGFloat) {
        let adjustedY = min(max(locationY - 10, 0), trackHeight)
        let progress = 1 - (adjustedY / trackHeight)
        let newValue = Int((progress * 24).rounded())
        onValueChange(newValue)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .modelContainer(TaskManager.previewContainer)
    }
}
