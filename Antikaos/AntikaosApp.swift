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
    init() {
        FontLoader.loadCustomFonts(["Schoolbell-Regular.ttf"])
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
            TaskManager.seedSampleDataIfNeeded(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    private func configureAppearance() {
        let accent = UIColor(red: 216 / 255, green: 113 / 255, blue: 66 / 255, alpha: 1)
        let titleFont = UIFont(name: "Schoolbell-Regular", size: 20) ?? .systemFont(ofSize: 20, weight: .regular)
        let largeTitleFont = UIFont(name: "Schoolbell-Regular", size: 30) ?? .systemFont(ofSize: 30, weight: .regular)
        let tabFont = UIFont(name: "Schoolbell-Regular", size: 14) ?? .systemFont(ofSize: 14, weight: .regular)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = UIColor.clear
        navAppearance.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        navAppearance.largeTitleTextAttributes = [
            .font: largeTitleFont,
            .foregroundColor: UIColor.black
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = accent

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundColor = UIColor(red: 250 / 255, green: 245 / 255, blue: 241 / 255, alpha: 0.95)
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
        tabAppearance.inlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
        tabAppearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        tabAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
        tabAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = accent
    }
}
