import SwiftUI
import SwiftData
import StoreKit

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premiumAccessManager: PremiumAccessManager
    @AppStorage("profile.userName") private var userName = ""
    @Query(sort: \TaskItem.updatedAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \HistoryEntry.date, order: .reverse) private var historyEntries: [HistoryEntry]
    @Query(sort: \modelHorasDisponiveis.updatedAt, order: .reverse) private var availableHoursModels: [modelHorasDisponiveis]
    @State private var isEditingAvailableHours = false
    @State private var isEditingUserName = false
    @State private var isHistoryExpanded = false
    @State private var draftUserName = ""
    @State private var isShowingChaosInfo = false
    @State private var isShowingHistoryPaywall = false

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

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:
            return "Bom dia,"
        case 12..<18:
            return "Boa tarde,"
        default:
            return "Boa noite,"
        }
    }

    private var todayChaosLevel: ChaosLevel {
        ChaosLevel(value: ChaosCalculator.overallChaos(for: tasks))
    }

    private var weeklyAvailableHoursText: String {
        guard let availableHours = availableHoursModels.first else { return "0h" }
        let minutes = AvailableWeekday.allCases.reduce(0) { $0 + availableHours.minutes(for: $1) }
        return modelHorasDisponiveis.formattedTime(minutes: minutes)
    }

    private var chaosDisplayName: String {
        let label = AppStrings.localized(todayChaosLevel.titleKey)
        return label.replacingOccurrences(of: "Caos ", with: "")
    }

    private var weeklyChaosDisplayName: String {
        let label = AppStrings.localized(ChaosLevel(value: averageWeeklyChaos).titleKey)
        return label.replacingOccurrences(of: "Caos ", with: "")
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 390
            let isVeryCompact = proxy.size.width < 370

            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: isVeryCompact ? 14 : 18) {
                        headerSection(isCompact: isCompact, isVeryCompact: isVeryCompact)
                        overviewSection(isCompact: isCompact, isVeryCompact: isVeryCompact)
                        availableHoursSection
                        historySection(isCompact: isCompact, isVeryCompact: isVeryCompact)
                    }
                    .padding(.horizontal, isVeryCompact ? 16 : 20)
                    .padding(.vertical, isVeryCompact ? 14 : 18)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .dismissKeyboardOnTap()
        .onAppear {
            createAvailableHoursModelIfNeeded()
            resetDraftUserName()
        }
        .sheet(isPresented: $isShowingHistoryPaywall) {
            UnlimitedHistoryPaywallView()
                .environmentObject(premiumAccessManager)
                .presentationDetents([.medium, .large])
        }
    }

    private func headerSection(isCompact: Bool, isVeryCompact: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(greetingText)
                    .font(AppTheme.schoolbell(isVeryCompact ? 20 : 22))
                    .foregroundStyle(AppTheme.primaryText)

                if isEditingUserName {
                    HStack(spacing: 10) {
                        TextField("Nome", text: $draftUserName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(AppTheme.schoolbell(24))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Button("Salvar") {
                            saveDraftUserName()
                        }
                        .font(AppTheme.schoolbell(18))
                        .foregroundStyle(Color.white)
                        .frame(height: 46)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(trimmedDraftUserName.isEmpty ? AppTheme.secondaryText.opacity(0.35) : AppTheme.primaryChaos)
                        )
                        .disabled(trimmedDraftUserName.isEmpty)
                    }
                } else {
                    Text(profileHeaderTitle)
                        .font(AppTheme.schoolbell(isVeryCompact ? 36 : (isCompact ? 40 : 44)))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                Text("Seu caos está \(chaosDisplayName.lowercased()) hoje.")
                    .font(AppTheme.schoolbell(isVeryCompact ? 18 : 20))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 10)

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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryChaos)
                    .frame(width: isVeryCompact ? 38 : 42, height: isVeryCompact ? 38 : 42)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.72))
                            .overlay {
                                Circle()
                                    .stroke(AppTheme.primaryText.opacity(0.12), lineWidth: 1)
                            }
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func overviewSection(isCompact: Bool, isVeryCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Visão geral")
                        .font(AppTheme.schoolbell(isVeryCompact ? 22 : 24))
                        .foregroundStyle(AppTheme.primaryChaos)

                    HStack(spacing: 8) {
                        Text("Caos médio da semana")
                            .font(AppTheme.schoolbell(isVeryCompact ? 16 : 18))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Button {
                            withAnimation(.snappy(duration: 0.22)) {
                                isShowingChaosInfo.toggle()
                            }
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("\(averageWeeklyChaos)/100")
                        .font(AppTheme.schoolbell(isVeryCompact ? 24 : 28))
                        .foregroundStyle(ChaosLevel(value: averageWeeklyChaos).tint)

                    Text(weeklyChaosDisplayName)
                        .font(AppTheme.schoolbell(isVeryCompact ? 16 : 18))
                        .foregroundStyle(ChaosLevel(value: averageWeeklyChaos).tint)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(ChaosLevel(value: averageWeeklyChaos).tint.opacity(0.14))
                                .overlay {
                                    Capsule()
                                        .stroke(ChaosLevel(value: averageWeeklyChaos).tint.opacity(0.18), lineWidth: 1)
                                }
                        )
                }
            }

            Divider()
                .overlay(AppTheme.primaryText.opacity(0.08))

            if isVeryCompact {
                VStack(spacing: 14) {
                    overviewMetric(
                        value: AppStrings.integerValue(completedTasksCount),
                        title: "Tarefas\nconcluídas",
                        tint: AppTheme.supportGreen,
                        isVeryCompact: isVeryCompact
                    )

                    Divider()
                        .overlay(AppTheme.primaryText.opacity(0.08))

                    overviewMetric(
                        value: AppStrings.integerValue(completedSessionsCount),
                        title: "Sessões\nrealizadas",
                        tint: AppTheme.primaryChaos,
                        isVeryCompact: isVeryCompact
                    )

                    Divider()
                        .overlay(AppTheme.primaryText.opacity(0.08))

                    overviewMetric(
                        value: weeklyAvailableHoursText,
                        title: "Tempo disponível\nesta semana",
                        tint: AppTheme.supportGreen,
                        isVeryCompact: isVeryCompact
                    )
                }
            } else {
                HStack(spacing: 0) {
                    overviewMetric(
                        value: AppStrings.integerValue(completedTasksCount),
                        title: "Tarefas\nconcluídas",
                        tint: AppTheme.supportGreen,
                        isVeryCompact: isVeryCompact
                    )

                    overviewDivider(isVeryCompact: isVeryCompact)

                    overviewMetric(
                        value: AppStrings.integerValue(completedSessionsCount),
                        title: "Sessões\nrealizadas",
                        tint: AppTheme.primaryChaos,
                        isVeryCompact: isVeryCompact
                    )

                    overviewDivider(isVeryCompact: isVeryCompact)

                    overviewMetric(
                        value: weeklyAvailableHoursText,
                        title: "Tempo disponível\nesta semana",
                        tint: AppTheme.supportGreen,
                        isVeryCompact: isVeryCompact
                    )
                }
            }
        }
        .softCard()
        .overlay(alignment: .topTrailing) {
            if isShowingChaosInfo {
                chaosInfoBubble
                    .offset(x: -16, y: 16)
            }
        }
    }

    private func overviewMetric(value: String, title: String, tint: Color, isVeryCompact: Bool) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(AppTheme.schoolbell(isVeryCompact ? 26 : 31))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(AppTheme.schoolbell(isVeryCompact ? 14 : 15))
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }

    private func overviewDivider(isVeryCompact: Bool) -> some View {
        Rectangle()
            .fill(AppTheme.primaryText.opacity(0.08))
            .frame(width: 1, height: isVeryCompact ? 96 : 116)
    }

    private var chaosInfoBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("O caos combina dificuldade, prazo e progresso das suas tarefas.")
                .font(AppTheme.schoolbell(15))
                .foregroundStyle(AppTheme.primaryText)

            Button("Entendi") {
                withAnimation(.snappy(duration: 0.22)) {
                    isShowingChaosInfo = false
                }
            }
            .font(AppTheme.schoolbell(15))
            .foregroundStyle(AppTheme.primaryChaos)
        }
        .padding(14)
        .frame(maxWidth: 220, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.primaryChaos.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var availableHoursSection: some View {
        if let availableHours = availableHoursModels.first {
            AvailableHoursCard(
                availableHours: availableHours,
                isEditing: $isEditingAvailableHours,
                onChange: saveAvailableHours,
                isCompact: UIScreen.main.bounds.width < 390,
                isVeryCompact: UIScreen.main.bounds.width < 370
            )
        }
    }

    private func historySection(isCompact: Bool, isVeryCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(AppStrings.localized("history.title"))
                    .font(AppTheme.schoolbell(isVeryCompact ? 22 : 24))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                if historyEntries.count > 3 {
                    Button {
                        if premiumAccessManager.hasUnlimitedHistory {
                            withAnimation(.snappy(duration: 0.24)) {
                                isHistoryExpanded.toggle()
                            }
                        } else {
                            isShowingHistoryPaywall = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(
                                premiumAccessManager.hasUnlimitedHistory
                                ? (isHistoryExpanded ? "Ver menos" : "Ver mais")
                                : "Ver mais"
                            )
                                .font(AppTheme.schoolbell(isVeryCompact ? 16 : 18))
                            Image(systemName: premiumAccessManager.hasUnlimitedHistory && isHistoryExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.primaryChaos)
                    }
                    .buttonStyle(.plain)
                }
            }

            if historyEntries.isEmpty {
                Text(AppStrings.localized("history.empty"))
                    .font(AppTheme.schoolbell(16))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    let visibleEntries = (premiumAccessManager.hasUnlimitedHistory && isHistoryExpanded)
                        ? historyEntries
                        : Array(historyEntries.prefix(3))

                    ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: iconName(for: entry.type))
                                .foregroundStyle(color(for: entry.type))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.message)
                                    .font(AppTheme.schoolbell(isVeryCompact ? 16 : 18))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text(AppStrings.historyDate(entry.date))
                                    .font(AppTheme.schoolbell(isVeryCompact ? 13 : 14))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer()

                            Text(AppStrings.scoreCompact(entry.chaosValue))
                                .font(AppTheme.schoolbell(isVeryCompact ? 13 : 14))
                                .foregroundStyle(ChaosLevel(value: entry.chaosValue).tint)
                        }
                        .padding(.vertical, 12)

                        if index < visibleEntries.count - 1 {
                            Divider()
                                .overlay(AppTheme.primaryText.opacity(0.08))
                        }
                    }
                }
            }
        }
        .softCard()
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

private struct UnlimitedHistoryPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var premiumAccessManager: PremiumAccessManager

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Histórico ilimitado")
                        .font(AppTheme.schoolbell(30))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Veja todo o seu histórico e acompanhe sua evolução sem limite. Ideal para a proposta 1 Dollar App: uma compra única simples.")
                        .font(AppTheme.schoolbell(18))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 12) {
                    benefitRow("Acesse todos os registros antigos")
                    benefitRow("Acompanhe sua consistência ao longo do tempo")
                    benefitRow("Desbloqueio permanente por compra única")
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(AppTheme.primaryChaos.opacity(0.16), lineWidth: 1)
                        )
                )

                ProductView(id: PremiumAccessManager.unlimitedHistoryProductID)
                    .productViewStyle(.large)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(AppTheme.primaryChaos.opacity(0.18), lineWidth: 1)
                            )
                    )

                Button {
                    Task {
                        await premiumAccessManager.restorePurchases()
                    }
                } label: {
                    Text("Restaurar compra")
                        .font(AppTheme.schoolbell(18))
                        .foregroundStyle(AppTheme.primaryChaos)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.primaryChaos.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .onAppear {
            Task {
                await premiumAccessManager.refreshEntitlements()
            }
        }
        .onChange(of: premiumAccessManager.hasUnlimitedHistory) { _, isUnlocked in
            if isUnlocked {
                dismiss()
            }
        }
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.primaryChaos)

            Text(text)
                .font(AppTheme.schoolbell(16))
                .foregroundStyle(AppTheme.primaryText)
        }
    }
}

struct AvailableHoursCard: View {
    @Bindable var availableHours: modelHorasDisponiveis
    @Binding var isEditing: Bool
    let onChange: () -> Void
    var isCompact: Bool = false
    var isVeryCompact: Bool = false
    var showsHeader = true
    var allowsEditingToggle = true
    @State private var draftMinutes: [AvailableWeekday: Int] = [:]
    @State private var pickerDay: AvailableWeekday?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                                .font(AppTheme.schoolbell(isVeryCompact ? 17 : (isCompact ? 18 : 20)))
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(width: isVeryCompact ? 34 : (isCompact ? 38 : 44), alignment: .leading)

                            Slider(
                                value: Binding(
                                    get: { Double(displayedMinutes(for: day)) },
                                    set: { draftMinutes[day] = snappedMinutes(Int($0.rounded())) }
                                ),
                                in: 0...(24 * 60),
                                step: 15
                            )
                            .tint(AppTheme.primaryChaos)
                            .disabled(!isEditing)

                            Text(modelHorasDisponiveis.formattedTime(minutes: displayedMinutes(for: day)))
                                .font(AppTheme.schoolbell(isVeryCompact ? 15 : (isCompact ? 16 : 18)))
                                .foregroundStyle(AppTheme.primaryChaos)
                                .frame(width: isVeryCompact ? 58 : (isCompact ? 68 : 82), alignment: .trailing)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .buttonStyle(.plain)
                }

                totalWeeklyCard
            }

            if !showsHeader {
                HStack {
                    Spacer()
                    saveButton
                }
            }
        }
        .softCard()
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
                    ForEach(stride(from: 0, through: 24 * 60, by: 15).map { $0 }, id: \.self) { minutes in
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
            Text("Meu tempo disponível")
                .font(AppTheme.schoolbell(isVeryCompact ? 21 : (isCompact ? 22 : 24)))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Spacer()

            saveButton

            if allowsEditingToggle {
                editButton
            }
        }
    }

    private var totalWeeklyCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(AppTheme.primaryChaos.opacity(0.14))
                .frame(width: isVeryCompact ? 46 : 52, height: isVeryCompact ? 46 : 52)
                .overlay {
                    Image(systemName: "clock")
                        .font(.system(size: isVeryCompact ? 18 : 22, weight: .regular))
                        .foregroundStyle(AppTheme.primaryChaos)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("Total semanal")
                    .font(AppTheme.schoolbell(isVeryCompact ? 15 : 17))
                    .foregroundStyle(AppTheme.secondaryText)

                Text(modelHorasDisponiveis.formattedTime(minutes: weeklyTotalMinutes))
                    .font(AppTheme.schoolbell(isVeryCompact ? 21 : (isCompact ? 22 : 24)))
                    .foregroundStyle(AppTheme.primaryChaos)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            Text("70h disponíveis")
                .font(AppTheme.schoolbell(isVeryCompact ? 14 : (isCompact ? 15 : 17)))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.primaryText.opacity(0.08), lineWidth: 1)
                )
        )
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
                        .font(AppTheme.schoolbell(isVeryCompact ? 16 : 18))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, isVeryCompact ? 12 : 14)
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
        min(max(Int((Double(value) / 15).rounded()) * 15, 0), 24 * 60)
    }
}

private struct RecentActivityListView: View {
    let entries: [HistoryEntry]
    let colorForType: (HistoryEntryType) -> Color
    let title: String

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(entries) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(colorForType(entry.type).opacity(0.85))
                                .frame(width: 14, height: 14)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.message)
                                    .font(AppTheme.schoolbell(18))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text(AppStrings.historyDate(entry.date))
                                    .font(AppTheme.schoolbell(15))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer()
                        }
                        .softCard()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .modelContainer(TaskManager.previewContainer)
    }
}
