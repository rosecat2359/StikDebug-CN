//
//  Localization.swift
//  StikDebug
//
//  Runtime language switching support.
//
//  The app ships two languages: English (source) and Simplified Chinese.
//  Every user-visible string lives in `Localizable.xcstrings` keyed by its
//  English source text, so English is used as-is when a translation is missing.
//
//  SwiftUI resolves `Text("...")` (and every other `LocalizedStringKey` based
//  view) against the locale found in the environment. Pushing the selected
//  locale into the environment and rebuilding the view tree is therefore enough
//  to switch the whole interface without relaunching the app.
//
//  Strings that are built in Swift code instead of being passed to SwiftUI as
//  `LocalizedStringKey` must be marked with `.localized`, which reads from the
//  same string table through `LanguageManager` so it switches instantly too.
//

import Foundation
import SwiftUI

// MARK: - Language

enum AppLanguage: String, CaseIterable, Identifiable {
    /// Follow the device language (Chinese devices get Simplified Chinese).
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    /// The language code used for `Locale` and for the matching `.lproj` folder.
    var localeIdentifier: String {
        switch self {
        case .system:
            return LanguageManager.systemLanguageCode
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }

    /// Name shown in the language picker. Each language is written in itself so
    /// the picker stays readable no matter which language is active.
    var displayName: String {
        switch self {
        case .system:
            return "Follow System".localized
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}

// MARK: - Language manager

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    /// `UserDefaults` key holding the user's language choice.
    static let storageKey = "appLanguage"

    /// Key read by iOS to localize the app bundle itself.
    private static let appleLanguagesKey = "AppleLanguages"

    @Published private(set) var language: AppLanguage

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        language = stored.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// Locale handed to SwiftUI so every `LocalizedStringKey` is resolved with it.
    var locale: Locale {
        Locale(identifier: language.localeIdentifier)
    }

    /// Changes whenever the effective language changes; used as a view identity
    /// so the whole tree is rebuilt and re-localized.
    var refreshToken: String {
        language.localeIdentifier
    }

    var isChinese: Bool {
        language.localeIdentifier.hasPrefix("zh")
    }

    func select(_ newLanguage: AppLanguage) {
        guard newLanguage != language else { return }
        language = newLanguage
        UserDefaults.standard.set(newLanguage.rawValue, forKey: Self.storageKey)
        applyAppleLanguages()
    }

    /// Keeps the bundle level language in sync so system-provided UI (alerts,
    /// share sheets, keyboards) and the next launch use the same language.
    private func applyAppleLanguages() {
        let defaults = UserDefaults.standard
        switch language {
        case .system:
            defaults.removeObject(forKey: Self.appleLanguagesKey)
        case .english, .simplifiedChinese:
            defaults.set([language.localeIdentifier], forKey: Self.appleLanguagesKey)
        }
        defaults.synchronize()
    }

    /// The device language restricted to the languages this app ships with.
    static var systemLanguageCode: String {
        let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
        return preferred.hasPrefix("zh") ? "zh-Hans" : "en"
    }

    // MARK: String lookup

    func localizedString(for key: String) -> String {
        // English is the source language, so the key itself is always the
        // correct English text. Returning it directly also avoids falling back
        // to a translation when the bundle has no `en.lproj`.
        guard language.localeIdentifier != "en" else { return key }

        if let path = Bundle.main.path(forResource: language.localeIdentifier, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return key
    }
}

// MARK: - String helpers

extension String {
    /// Localized version of the receiver using the currently selected language.
    var localized: String {
        LanguageManager.shared.localizedString(for: self)
    }

    /// Localized format string with arguments, e.g. `"Delete %@?".localized(name)`.
    func localized(_ arguments: CVarArg...) -> String {
        String(format: LanguageManager.shared.localizedString(for: self), arguments: arguments)
    }
}
