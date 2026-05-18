import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: AppTab = .overview

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
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
