import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: AppTab = .overview

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .overview:
                    NavigationStack { DashboardView() }
                case .tasks:
                    NavigationStack { TasksView() }
                case .profile:
                    NavigationStack { ProfileView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
        }
        .animation(.snappy(duration: 0.24), value: selectedTab)
    }
}

private enum AppTab: Hashable {
    case overview
    case tasks
    case profile
}

private struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            sideTab(
                tab: .overview,
                icon: "circle.inset.filled",
                title: AppStrings.localized("tab.overview")
            )

            centerTab

            sideTab(
                tab: .profile,
                icon: "gearshape",
                title: AppStrings.localized("tab.profile")
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.paper)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppTheme.ink.opacity(0.18), lineWidth: 1.2)
                )
                .shadow(color: AppTheme.ink.opacity(0.12), radius: 18, x: 0, y: 10)
        )
    }

    private func sideTab(tab: AppTab, icon: String, title: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selectedTab == tab ? AppTheme.ink : AppTheme.secondaryText)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(selectedTab == tab ? AppTheme.ink : AppTheme.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var centerTab: some View {
        Button {
            selectedTab = .tasks
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(selectedTab == .tasks ? AppTheme.primaryChaos : AppTheme.paper)
                        .frame(width: 58, height: 58)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.ink.opacity(0.24), lineWidth: 1.4)
                        )

                    Circle()
                        .stroke(AppTheme.ink.opacity(0.14), lineWidth: 1)
                        .frame(width: 34, height: 34)

                    Image(systemName: "checklist")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selectedTab == .tasks ? AppTheme.paper : AppTheme.ink)
                }
                .offset(y: -18)

                Text(AppStrings.localized("tab.tasks"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(selectedTab == .tasks ? AppTheme.ink : AppTheme.secondaryText)
                    .padding(.top, -10)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(TaskManager.previewContainer)
}
