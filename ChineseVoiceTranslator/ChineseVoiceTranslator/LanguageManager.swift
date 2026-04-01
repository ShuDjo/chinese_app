import Foundation
import Combine

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case serbianCyrillic = "sr-Cyrl"
    case serbianLatin = "sr-Latn"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .serbianCyrillic: return "Српски (ћирилица)"
        case .serbianLatin: return "Srpski (latinica)"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .serbianCyrillic, .serbianLatin: return "🇷🇸"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        language = AppLanguage(rawValue: saved) ?? .english
    }

    var s: Strings { Strings(language) }
}
