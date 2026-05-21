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
                        .font(AppTheme.schoolbell(34))
                        .foregroundStyle(AppTheme.primaryText)
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
                    .font(AppTheme.schoolbell(24))
                    .foregroundStyle(AppTheme.primaryText)

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
                        .foregroundStyle(isEditingUserName ? Color.white : AppTheme.primaryChaos)
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
                        .font(AppTheme.schoolbell(18))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button("Salvar") {
                        saveDraftUserName()
                    }
                    .font(AppTheme.schoolbell(18))
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
                    .font(AppTheme.schoolbell(20))
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
                    .font(AppTheme.schoolbell(18))
                    .foregroundStyle(AppTheme.primaryText)

                Text(value)
                    .font(AppTheme.schoolbell(28))
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
                .font(AppTheme.schoolbell(24))
                .foregroundStyle(AppTheme.primaryText)

            if historyEntries.isEmpty {
                Text(AppStrings.localized("history.empty"))
                    .font(AppTheme.schoolbell(16))
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
                                .font(AppTheme.schoolbell(18))
                                .foregroundStyle(AppTheme.primaryText)

                            Text(AppStrings.historyDate(entry.date))
                                .font(AppTheme.schoolbell(14))
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
            return AppTheme.primaryChaos
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
    @State private var draftMinutes: [AvailableWeekday: Int] = [:]
    @State private var pickerDay: AvailableWeekday?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                header
            }

            VStack(spacing: 16) {
                ForEach(AvailableWeekday.allCases) { day in
                    Button {
                        if isEditing {
                            pickerDay = day
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(day.shortTitle.capitalized)
                                .font(AppTheme.schoolbell(20))
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(width: 44, alignment: .leading)

                            Slider(
                                value: Binding(
                                    get: { Double(displayedMinutes(for: day)) },
                                    set: { draftMinutes[day] = snappedMinutes(Int($0.rounded())) }
                                ),
                                in: 0...480,
                                step: 15
                            )
                            .tint(AppTheme.primaryChaos)
                            .disabled(!isEditing)

                            Text(modelHorasDisponiveis.formattedTime(minutes: displayedMinutes(for: day)))
                                .font(AppTheme.schoolbell(18))
                                .foregroundStyle(AppTheme.primaryChaos)
                                .frame(width: 82, alignment: .trailing)
                        }
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Image(systemName: "clock")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(AppTheme.primaryChaos)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total semanal")
                            .font(AppTheme.schoolbell(18))
                            .foregroundStyle(AppTheme.secondaryText)

                        Text(modelHorasDisponiveis.formattedTime(minutes: weeklyTotalMinutes))
                            .font(AppTheme.schoolbell(24))
                            .foregroundStyle(AppTheme.primaryChaos)
                    }

                    Spacer()
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.45))
            )

            if !showsHeader {
                HStack {
                    Spacer()
                    saveButton
                }
            }
        }
        .onAppear(perform: resetDraftHours)
        .sheet(item: $pickerDay) { day in
            VStack(spacing: 10) {
                HStack {
                    Button("Cancelar") {
                        pickerDay = nil
                    }
                    .font(AppTheme.schoolbell(18))
                    .foregroundStyle(AppTheme.primaryChaos)

                    Spacer()

                    Text(day.shortTitle.capitalized)
                        .font(AppTheme.schoolbell(24))

                    Spacer()

                    Button("Salvar") {
                        pickerDay = nil
                    }
                    .font(AppTheme.schoolbell(18))
                    .foregroundStyle(AppTheme.primaryChaos)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Picker("Horas", selection: Binding(
                    get: { displayedMinutes(for: day) },
                    set: { draftMinutes[day] = snappedMinutes($0) }
                )) {
                    ForEach(stride(from: 0, through: 480, by: 15).map { $0 }, id: \.self) { minutes in
                        Text(modelHorasDisponiveis.formattedTime(minutes: minutes))
                            .tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
            }
            .presentationDetents([.height(320)])
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Meu tempo disponível:")
                .font(AppTheme.schoolbell(24))
                .foregroundStyle(AppTheme.primaryText)

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
                        .font(AppTheme.schoolbell(18))
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
                .foregroundStyle(isEditing ? Color.white : AppTheme.primaryChaos)
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

    private func displayedMinutes(for day: AvailableWeekday) -> Int {
        if isEditing {
            return draftMinutes[day] ?? availableHours.minutes(for: day)
        }

        return availableHours.minutes(for: day)
    }

    private func resetDraftHours() {
        draftMinutes = Dictionary(
            uniqueKeysWithValues: AvailableWeekday.allCases.map { day in
                (day, availableHours.minutes(for: day))
            }
        )
    }

    private func applyDraftHours() {
        for day in AvailableWeekday.allCases {
            availableHours.setMinutes(draftMinutes[day] ?? availableHours.minutes(for: day), for: day)
        }
    }

    private var weeklyTotalMinutes: Int {
        AvailableWeekday.allCases.reduce(0) { partialResult, day in
            partialResult + displayedMinutes(for: day)
        }
    }

    private func snappedMinutes(_ value: Int) -> Int {
        min(max(Int((Double(value) / 15).rounded()) * 15, 0), 480)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .modelContainer(TaskManager.previewContainer)
    }
}
