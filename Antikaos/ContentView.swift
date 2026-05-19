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
    @State private var isEditingOnboardingAvailableHours = true
    @FocusState private var isOnboardingNameFocused: Bool

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
        .onAppear {
            onboardingName = userName
            createAvailableHoursModelIfNeeded()
        }
    }

    private var nameOnboardingScreen: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Como podemos chamar você?")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                TextField("", text: $onboardingName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isOnboardingNameFocused)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onSubmit(saveOnboardingName)

                Text("É possível alterar na tela Perfil")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)

                Button(action: saveOnboardingName) {
                    Text("Continuar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(trimmedOnboardingName.isEmpty ? Color.white.opacity(0.18) : AppTheme.primaryChaos)
                        )
                }
                .buttonStyle(.plain)
                .disabled(trimmedOnboardingName.isEmpty)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 420)
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
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Qual a sua disponibilidade?")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                if let availableHours = availableHoursModels.first {
                    AvailableHoursCard(
                        availableHours: availableHours,
                        isEditing: $isEditingOnboardingAvailableHours,
                        onChange: saveOnboardingAvailableHours,
                        showsHeader: false,
                        allowsEditingToggle: false
                    )
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }

                Text("É possível alterar na tela Perfil")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 500)
        }
        .onAppear {
            isEditingOnboardingAvailableHours = true
            createAvailableHoursModelIfNeeded()
        }
    }

    private func createAvailableHoursModelIfNeeded() {
        guard availableHoursModels.isEmpty else { return }

        modelContext.insert(modelHorasDisponiveis())
        try? modelContext.save()
    }

    private func saveOnboardingAvailableHours() {
        TaskManager(modelContext: modelContext).rebalanceGeneratedTasks()
        didCompleteAvailableHoursOnboarding = true
    }

    private var launchScreen: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.12)
                .ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 18) {
                    ChaosCircle(value: overallChaos)
                        .environment(\.colorScheme, .dark)

                    Text(AppStrings.localized(ChaosLevel(value: overallChaos).titleKey))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.92))

                    Text(focusClockString(for: context.date))
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.82))

                    BlinkingFocusHint()
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
    @State private var isVisible = true

    var body: some View {
        Text(AppStrings.localized("focus.tapToReturn"))
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.white.opacity(isVisible ? 0.76 : 0.18))
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
