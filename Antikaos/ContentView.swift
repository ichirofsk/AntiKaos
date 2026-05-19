import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \TaskItem.deadlineDate) private var tasks: [TaskItem]
    @State private var selectedTab: AppTab = .overview
    @State private var isShowingLaunchScreen = true

    private var overallChaos: Int {
        ChaosCalculator.overallChaos(for: tasks)
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

            if isShowingLaunchScreen {
                launchScreen
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: isShowingLaunchScreen)
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
