//
//  AntikaosApp.swift
//  Antikaos
//
//  Created by Antônio Girardello Miguel on 15/05/26.
//

import SwiftUI
import SwiftData

@main
struct AntikaosApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
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
}
