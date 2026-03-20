//
//  ChineseVoiceTranslatorApp.swift
//  ChineseVoiceTranslator
//
//  Created by Djordje Petkovic on 25. 11. 2025..
//

import SwiftUI
import SwiftData

@main
struct ChineseVoiceTranslatorApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
            TabView {
                ContentView()
                    .tabItem { Label("Translate", systemImage: "mic.fill") }
                QuizView()
                    .tabItem { Label("Quiz", systemImage: "list.bullet.clipboard") }
            }
            .tint(Theme.red)
        }
        .modelContainer(sharedModelContainer)
    }
}
