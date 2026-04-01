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
    @StateObject private var langManager = LanguageManager.shared

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
                    .tabItem { Label(langManager.s.tabTranslate, systemImage: "mic.fill") }
                QuizView()
                    .tabItem { Label(langManager.s.tabExam, systemImage: "graduationcap") }
                CharacterView()
                    .tabItem { Label(langManager.s.tabCharacters, systemImage: "character") }
                FlashcardView()
                    .tabItem { Label(langManager.s.tabFlashCards, systemImage: "rectangle.stack.fill") }
                SettingsView()
                    .tabItem { Label(langManager.s.tabSettings, systemImage: "gear") }
            }
            .tint(Theme.red)
            .environmentObject(langManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
