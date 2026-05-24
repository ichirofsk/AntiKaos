//
//  AntikaosApp.swift
//  Antikaos
//
//  Created by Antônio Girardello Miguel on 15/05/26.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct AntikaosApp: App {
    @StateObject private var premiumAccessManager = PremiumAccessManager()

    init() {
        FontLoader.loadCustomFonts(["Schoolbell-Regular.ttf"])
        clearLegacyAppStateIfNeeded()
        configureAppearance()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            GeneratedTaskItem.self,
            HistoryEntry.self,
            modelHorasDisponiveis.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            TaskManager.removeLegacySampleDataIfNeeded(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .environmentObject(premiumAccessManager)
        }
        .modelContainer(sharedModelContainer)
    }

    private func configureAppearance() {
        let accent = UIColor(red: 216 / 255, green: 113 / 255, blue: 66 / 255, alpha: 1)
        let titleFont = UIFont(name: "Schoolbell-Regular", size: 20) ?? .systemFont(ofSize: 20, weight: .regular)
        let largeTitleFont = UIFont(name: "Schoolbell-Regular", size: 30) ?? .systemFont(ofSize: 30, weight: .regular)
        let tabFont = UIFont(name: "Schoolbell-Regular", size: 14) ?? .systemFont(ofSize: 14, weight: .regular)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(red: 244 / 255, green: 237 / 255, blue: 232 / 255, alpha: 1)
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        navAppearance.largeTitleTextAttributes = [
            .font: largeTitleFont,
            .foregroundColor: UIColor.black
        ]
        navAppearance.buttonAppearance.normal.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: accent
        ]
        navAppearance.doneButtonAppearance.normal.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: accent
        ]
        navAppearance.backButtonAppearance.normal.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: accent
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = accent

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 250 / 255, green: 245 / 255, blue: 241 / 255, alpha: 0.95)
        tabAppearance.shadowColor = .clear
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: tabFont,
            .foregroundColor: UIColor.black.withAlphaComponent(0.62)
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: tabFont,
            .foregroundColor: accent
        ]
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        tabAppearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 6)
        tabAppearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 6)
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.black.withAlphaComponent(0.62)
        tabAppearance.stackedLayoutAppearance.selected.iconColor = accent
        tabAppearance.inlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
        tabAppearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        tabAppearance.inlineLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 6)
        tabAppearance.inlineLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 6)
        tabAppearance.inlineLayoutAppearance.normal.iconColor = UIColor.black.withAlphaComponent(0.62)
        tabAppearance.inlineLayoutAppearance.selected.iconColor = accent
        tabAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
        tabAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        tabAppearance.compactInlineLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 6)
        tabAppearance.compactInlineLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 6)
        tabAppearance.compactInlineLayoutAppearance.normal.iconColor = UIColor.black.withAlphaComponent(0.62)
        tabAppearance.compactInlineLayoutAppearance.selected.iconColor = accent

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = accent
        UITabBar.appearance().unselectedItemTintColor = UIColor.black.withAlphaComponent(0.62)
    }

    private func clearLegacyAppStateIfNeeded() {
        let defaults = UserDefaults.standard
        let didResetLegacyState = defaults.bool(forKey: "app.didResetLegacyState")

        guard !didResetLegacyState else { return }

        defaults.removeObject(forKey: "profile.userName")
        defaults.removeObject(forKey: "profile.didCompleteAvailableHoursOnboarding")
        defaults.set(true, forKey: "app.didResetLegacyState")
    }
}
