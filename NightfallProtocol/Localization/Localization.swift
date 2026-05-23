import Foundation
import Observation
import SwiftUI

struct LocalizedString: Hashable {
    let key: String

    var swiftUIKey: LocalizedStringKey {
        LocalizedStringKey(key)
    }

    static func key(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(key)
    }
}

@MainActor
@Observable
final class LanguageManager {
    static let fallbackLanguage = "en"

    static let supportedLanguages: [LanguageOption] = [
        LanguageOption(id: "en", nameKey: "language.en", localeIdentifier: "en", isRightToLeft: false),
        LanguageOption(id: "es", nameKey: "language.es", localeIdentifier: "es", isRightToLeft: false),
        LanguageOption(id: "fr", nameKey: "language.fr", localeIdentifier: "fr", isRightToLeft: false),
        LanguageOption(id: "de", nameKey: "language.de", localeIdentifier: "de", isRightToLeft: false),
        LanguageOption(id: "pt", nameKey: "language.pt", localeIdentifier: "pt", isRightToLeft: false),
        LanguageOption(id: "it", nameKey: "language.it", localeIdentifier: "it", isRightToLeft: false),
        LanguageOption(id: "ja", nameKey: "language.ja", localeIdentifier: "ja", isRightToLeft: false),
        LanguageOption(id: "ko", nameKey: "language.ko", localeIdentifier: "ko", isRightToLeft: false),
        LanguageOption(id: "zh-Hans", nameKey: "language.zhHans", localeIdentifier: "zh-Hans", isRightToLeft: false),
        LanguageOption(id: "ar", nameKey: "language.ar", localeIdentifier: "ar", isRightToLeft: true),
        LanguageOption(id: "hi", nameKey: "language.hi", localeIdentifier: "hi", isRightToLeft: false)
    ]

    var selectedLanguageCode: String {
        didSet {
            UserDefaults.standard.set(selectedLanguageCode, forKey: Self.userDefaultsKey)
        }
    }

    private static let userDefaultsKey = "nightfall.selectedLanguage"

    init() {
        let persisted = UserDefaults.standard.string(forKey: Self.userDefaultsKey)
        selectedLanguageCode = persisted ?? Locale.current.language.languageCode?.identifier ?? Self.fallbackLanguage
        if !Self.supportedLanguages.contains(where: { $0.id == selectedLanguageCode }) {
            selectedLanguageCode = Self.fallbackLanguage
        }
    }

    var selectedLanguage: LanguageOption {
        Self.supportedLanguages.first(where: { $0.id == selectedLanguageCode }) ?? Self.supportedLanguages[0]
    }

    var locale: Locale {
        Locale(identifier: selectedLanguage.localeIdentifier)
    }

    var layoutDirection: LayoutDirection {
        selectedLanguage.isRightToLeft ? .rightToLeft : .leftToRight
    }

    func selectLanguage(id: String) {
        guard Self.supportedLanguages.contains(where: { $0.id == id }) else {
            selectedLanguageCode = Self.fallbackLanguage
            return
        }
        selectedLanguageCode = id
    }
}

@MainActor
final class LocalizationService {
    func string(_ key: String, languageCode: String, arguments: [CVarArg] = []) -> String {
        let locale = Locale(identifier: languageCode)
        let localized = String(localized: String.LocalizationValue(key), bundle: .main, locale: locale)

        guard !arguments.isEmpty else {
            return localized
        }

        return String(format: localized, locale: locale, arguments: arguments)
    }
}

struct LocalizedText: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(LocalizedStringKey(key))
    }
}

struct LocalizedValueText: View {
    @Environment(LanguageManager.self) private var languageManager
    @Environment(AppServices.self) private var services

    let key: String
    let arguments: [CVarArg]

    init(_ key: String, _ arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }

    var body: some View {
        Text(services.localization.string(key, languageCode: languageManager.selectedLanguageCode, arguments: arguments))
    }
}
