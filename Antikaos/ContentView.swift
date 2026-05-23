import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.deadlineDate) private var tasks: [TaskItem]
    @Query(sort: \modelHorasDisponiveis.updatedAt, order: .reverse) private var availableHoursModels: [modelHorasDisponiveis]
    @AppStorage("profile.userName") private var userName = ""
    @AppStorage("profile.didCompleteAvailableHoursOnboarding") private var didCompleteAvailableHoursOnboarding = false
    @State private var selectedTab: AppTab = .overview
    @State private var isShowingLaunchScreen = true
    @State private var onboardingName = ""
    @State private var isShowingAvailabilityInfo = false
    @State private var onboardingDraftMinutes: [AvailableWeekday: Int] = [:]
    @State private var pickerDay: AvailableWeekday?
    @FocusState private var isOnboardingNameFocused: Bool
    private let onboardingAccent = Color(red: 216 / 255, green: 113 / 255, blue: 66 / 255)
    private let onboardingBackground = Color(red: 244 / 255, green: 237 / 255, blue: 232 / 255)

    private var overallChaos: Int {
        ChaosCalculator.overallChaos(for: tasks)
    }

    private var trimmedOnboardingName: String {
        onboardingName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var needsNameOnboarding: Bool {
        userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var needsAvailableHoursOnboarding: Bool {
        !needsNameOnboarding && !didCompleteAvailableHoursOnboarding
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    DashboardView {
                        isShowingLaunchScreen = true
                    }
                }
                .tabItem {
                    Label(AppStrings.localized("tab.overview"), systemImage: "circle.grid.2x2.fill")
                }
                .tag(AppTab.overview)

                NavigationStack {
                    TasksView()
                }
                .tabItem {
                    Label(AppStrings.localized("tab.tasks"), systemImage: "checklist")
                }
                .tag(AppTab.tasks)

                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label(AppStrings.localized("tab.profile"), systemImage: "person.crop.circle")
                }
                .tag(AppTab.profile)
            }
            .tint(AppTheme.primaryChaos)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Color.white.opacity(0.92), for: .tabBar)
            .animation(.snappy(duration: 0.24), value: selectedTab)

            if needsNameOnboarding {
                nameOnboardingScreen
                    .transition(.opacity)
                    .zIndex(2)
            } else if needsAvailableHoursOnboarding {
                availabilityOnboardingScreen
                    .transition(.opacity)
                    .zIndex(2)
            } else if isShowingLaunchScreen {
                launchScreen
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: isShowingLaunchScreen)
        .animation(.easeInOut(duration: 0.24), value: needsNameOnboarding)
        .animation(.easeInOut(duration: 0.24), value: needsAvailableHoursOnboarding)
        .dismissKeyboardOnTap()
        .onAppear {
            onboardingName = userName
            createAvailableHoursModelIfNeeded()
            NotificationManager.requestAuthorizationIfNeeded()
        }
    }

    private var nameOnboardingScreen: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let isCompact = width < 390
            let isVeryCompact = width < 370
            let horizontalPadding = isVeryCompact ? 22.0 : 28.0
            let circleLarge = min(width * 0.68, isCompact ? 230 : 260)
            let circleSmall = min(width * 0.58, isCompact ? 190 : 220)
            let contentWidth = min(width - (horizontalPadding * 2), 420)

            ZStack {
                onboardingBackground
                    .ignoresSafeArea()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: circleLarge, height: circleLarge)
                        .blur(radius: isCompact ? 30 : 38)
                        .offset(x: width * 0.28, y: -proxy.size.height * 0.26)

                    Circle()
                        .fill(onboardingAccent.opacity(0.08))
                        .frame(width: circleSmall, height: circleSmall)
                        .blur(radius: isCompact ? 34 : 44)
                        .offset(x: -width * 0.32, y: proxy.size.height * 0.24)
                }
                .ignoresSafeArea()

                VStack(spacing: isVeryCompact ? 14 : 18) {
                    Text("Como podemos chamar você?")
                        .font(.custom("Schoolbell", size: isVeryCompact ? 24 : (isCompact ? 26 : 28)))
                        .foregroundStyle(Color.black.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, isVeryCompact ? 6 : 10)

                    HStack(spacing: 12) {
                        Image(systemName: "person")
                            .font(.system(size: isCompact ? 16 : 18, weight: .medium))
                            .foregroundStyle(Color.gray.opacity(0.9))

                        TextField("", text: $onboardingName, prompt: Text("Seu nome").font(.custom("Schoolbell", size: isCompact ? 16 : 18)).foregroundStyle(Color.black.opacity(0.74)))
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($isOnboardingNameFocused)
                            .font(.custom("Schoolbell", size: isCompact ? 18 : 20))
                            .foregroundStyle(Color.black.opacity(0.9))
                            .onSubmit(saveOnboardingName)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: isVeryCompact ? 54 : 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.52))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(onboardingAccent, lineWidth: 1)
                            )
                    )

                    Button(action: saveOnboardingName) {
                        Text("Continuar")
                            .font(.custom("Schoolbell", size: isVeryCompact ? 20 : 22))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: isVeryCompact ? 44 : 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(trimmedOnboardingName.isEmpty ? onboardingAccent.opacity(0.45) : onboardingAccent)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedOnboardingName.isEmpty)
                    .padding(.top, isVeryCompact ? 8 : 14)
                    .frame(maxWidth: min(contentWidth * 0.72, 260))
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: contentWidth)
                .offset(y: isVeryCompact ? -8 : -18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            isOnboardingNameFocused = true
        }
    }

    private func saveOnboardingName() {
        guard !trimmedOnboardingName.isEmpty else { return }
        userName = trimmedOnboardingName
        onboardingName = trimmedOnboardingName
        createAvailableHoursModelIfNeeded()
    }

    @ViewBuilder
    private var availabilityOnboardingScreen: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let isCompact = width < 390
            let isVeryCompact = width < 370
            let horizontalPadding = isVeryCompact ? 20.0 : 28.0
            let circleLarge = min(width * 0.68, isCompact ? 230 : 260)
            let circleSmall = min(width * 0.58, isCompact ? 190 : 220)

            ZStack {
                onboardingBackground
                    .ignoresSafeArea()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: circleLarge, height: circleLarge)
                        .blur(radius: isCompact ? 30 : 38)
                        .offset(x: width * 0.28, y: -proxy.size.height * 0.26)

                    Circle()
                        .fill(onboardingAccent.opacity(0.08))
                        .frame(width: circleSmall, height: circleSmall)
                        .blur(radius: isCompact ? 34 : 44)
                        .offset(x: -width * 0.32, y: proxy.size.height * 0.24)
                }
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: isVeryCompact ? 16 : 20) {
                    HStack(alignment: .top) {
                        Text("Qual a sua disponibilidade?")
                            .font(.custom("Schoolbell", size: isVeryCompact ? 24 : (isCompact ? 26 : 28)))
                            .foregroundStyle(Color.black.opacity(0.92))
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Button {
                            isShowingAvailabilityInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: isCompact ? 20 : 22, weight: .regular))
                                .foregroundStyle(Color.black.opacity(0.78))
                                .frame(width: isCompact ? 44 : 48, height: isCompact ? 44 : 48)
                                .background(Color.white.opacity(0.55), in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.72), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    if availableHoursModels.first != nil {
                        availabilityRowsCard(isCompact: isCompact, isVeryCompact: isVeryCompact)
                        weeklyTotalCard(isCompact: isCompact, isVeryCompact: isVeryCompact)
                        saveAvailabilityButton(isCompact: isCompact, isVeryCompact: isVeryCompact)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: min(width - (horizontalPadding * 2), 430))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .onAppear {
            createAvailableHoursModelIfNeeded()
            resetOnboardingDraftMinutes()
        }
        .alert("É possível alterar na tela Perfil", isPresented: $isShowingAvailabilityInfo) {
            Button("OK", role: .cancel) {}
        }
        .sheet(item: $pickerDay) { day in
            onboardingWheelPicker(day: day)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
    }

    private func createAvailableHoursModelIfNeeded() {
        guard availableHoursModels.isEmpty else { return }

        modelContext.insert(modelHorasDisponiveis())
        try? modelContext.save()
    }

    private func saveOnboardingAvailableHours() {
        guard let availableHours = availableHoursModels.first else { return }

        for day in AvailableWeekday.allCases {
            availableHours.setMinutes(
                onboardingDraftMinutes[day] ?? availableHours.minutes(for: day),
                for: day
            )
        }

        TaskManager(modelContext: modelContext).rebalanceGeneratedTasks()
        didCompleteAvailableHoursOnboarding = true
    }

    private func availabilityRowsCard(isCompact: Bool, isVeryCompact: Bool) -> some View {
        VStack(spacing: 16) {
            ForEach(AvailableWeekday.allCases) { day in
                onboardingAvailabilityRow(day: day, isCompact: isCompact, isVeryCompact: isVeryCompact)
            }
        }
        .padding(isVeryCompact ? 16 : 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.78), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)
        )
    }

    private func onboardingAvailabilityRow(day: AvailableWeekday, isCompact: Bool, isVeryCompact: Bool) -> some View {
        let minutes = displayedOnboardingMinutes(for: day)

        return Button {
            pickerDay = day
        } label: {
            HStack(spacing: 12) {
                Text(day.shortTitle.capitalized)
                    .font(.custom("Schoolbell", size: isVeryCompact ? 18 : 20))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .frame(width: isVeryCompact ? 36 : 42, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { Double(minutes) },
                        set: { onboardingDraftMinutes[day] = snappedMinutes(Int($0.rounded())) }
                    ),
                    in: 0...(24 * 60),
                    step: 15
                )
                .tint(onboardingAccent)

                Text(modelHorasDisponiveis.formattedTime(minutes: minutes))
                    .font(.custom("Schoolbell", size: isVeryCompact ? 16 : 18))
                    .foregroundStyle(onboardingAccent)
                    .frame(width: isVeryCompact ? 64 : 78, alignment: .trailing)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func weeklyTotalCard(isCompact: Bool, isVeryCompact: Bool) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: isVeryCompact ? 48 : 54, height: isVeryCompact ? 48 : 54)
                .overlay {
                    Image(systemName: "clock")
                        .font(.system(size: isVeryCompact ? 20 : 24, weight: .regular))
                        .foregroundStyle(onboardingAccent)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Total semanal")
                    .font(.custom("Schoolbell", size: isVeryCompact ? 16 : 18))
                    .foregroundStyle(Color.black.opacity(0.58))

                Text(modelHorasDisponiveis.formattedTime(minutes: onboardingWeeklyTotalMinutes))
                    .font(.custom("Schoolbell", size: isVeryCompact ? 22 : 24))
                    .foregroundStyle(onboardingAccent)
            }

            Spacer()
        }
        .padding(isVeryCompact ? 14 : 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.54))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.78), lineWidth: 1)
                )
        )
    }

    private func saveAvailabilityButton(isCompact: Bool, isVeryCompact: Bool) -> some View {
        Button(action: saveOnboardingAvailableHours) {
            Text("Salvar disponibilidade")
                .font(.custom("Schoolbell", size: isVeryCompact ? 21 : 24))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: isVeryCompact ? 52 : 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(onboardingAccent)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func onboardingWheelPicker(day: AvailableWeekday) -> some View {
        let binding = Binding<Int>(
            get: { displayedOnboardingMinutes(for: day) },
            set: { onboardingDraftMinutes[day] = snappedMinutes($0) }
        )

        return VStack(spacing: 10) {
                HStack {
                    Button("Cancelar") {
                        pickerDay = nil
                    }
                    .font(AppTheme.schoolbell(18))
                    .foregroundStyle(onboardingAccent)

                    Spacer()

                    Text(day.shortTitle.capitalized)
                        .font(.custom("Schoolbell", size: 22))

                Spacer()

                    Button("Salvar") {
                        pickerDay = nil
                    }
                    .font(AppTheme.schoolbell(18))
                    .foregroundStyle(onboardingAccent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Picker("Horas", selection: binding) {
                ForEach(stride(from: 0, through: 24 * 60, by: 15).map { $0 }, id: \.self) { minutes in
                    Text(modelHorasDisponiveis.formattedTime(minutes: minutes))
                        .font(.custom("Schoolbell", size: 22))
                        .tag(minutes)
                }
            }
            .pickerStyle(.wheel)
        }
    }

    private func displayedOnboardingMinutes(for day: AvailableWeekday) -> Int {
        if let value = onboardingDraftMinutes[day] {
            return value
        }

        return availableHoursModels.first?.minutes(for: day) ?? modelHorasDisponiveis().minutes(for: day)
    }

    private var onboardingWeeklyTotalMinutes: Int {
        AvailableWeekday.allCases.reduce(0) { partialResult, day in
            partialResult + displayedOnboardingMinutes(for: day)
        }
    }

    private func resetOnboardingDraftMinutes() {
        onboardingDraftMinutes = Dictionary(
            uniqueKeysWithValues: AvailableWeekday.allCases.map { day in
                (day, availableHoursModels.first?.minutes(for: day) ?? modelHorasDisponiveis().minutes(for: day))
            }
        )
    }

    private func snappedMinutes(_ value: Int) -> Int {
        min(max(Int((Double(value) / 15).rounded()) * 15, 0), 24 * 60)
    }

    private var launchScreen: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let isCompact = width < 390
            let circleLarge = min(width * 0.74, isCompact ? 250 : 280)
            let circleSmall = min(width * 0.62, isCompact ? 210 : 240)
            let chaosSize = min(width * 0.55, isCompact ? 190 : 208)

            ZStack {
                onboardingBackground
                    .ignoresSafeArea()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: circleLarge, height: circleLarge)
                        .blur(radius: isCompact ? 34 : 44)
                        .offset(x: width * 0.26, y: -proxy.size.height * 0.24)

                    Circle()
                        .fill(onboardingAccent.opacity(0.12))
                        .frame(width: circleSmall, height: circleSmall)
                        .blur(radius: isCompact ? 38 : 48)
                        .offset(x: -width * 0.26, y: proxy.size.height * 0.22)
                }
                .ignoresSafeArea()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: isCompact ? 14 : 18) {
                        ChaosCircle(value: overallChaos, size: chaosSize)

                        Text(AppStrings.localized(ChaosLevel(value: overallChaos).titleKey))
                            .font(.custom("Schoolbell", size: isCompact ? 22 : 24))
                            .foregroundStyle(Color.black.opacity(0.82))

                        Text(focusClockString(for: context.date))
                            .font(.system(size: isCompact ? 20 : 22, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.7))

                        BlinkingFocusHint(fontSize: isCompact ? 16 : 18)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isShowingLaunchScreen = false
        }
    }

    private func focusClockString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

private struct BlinkingFocusHint: View {
    var fontSize: CGFloat = 18
    @State private var isVisible = true

    var body: some View {
        Text(AppStrings.localized("focus.tapToReturn"))
            .font(.custom("Schoolbell", size: fontSize))
            .foregroundStyle(Color.black.opacity(isVisible ? 0.62 : 0.18))
            .multilineTextAlignment(.center)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isVisible)
            .onAppear {
                isVisible = false
            }
    }
}

private enum AppTab: Hashable {
    case overview
    case tasks
    case profile
}

#Preview {
    ContentView()
        .modelContainer(TaskManager.previewContainer)
}
