//
//  JiterkaApp.swift
//  Jiterka
//
//  Created by Alex K on 11/12/25.
//

import SwiftUI
import SwiftData

@main
struct JiterkaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Recording.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RecordingsView()
        }
        .modelContainer(sharedModelContainer)
    }
}
