//
//  L10n.swift
//  Docked
//
//  English first, French as a localization. A droplet runs inside Droppy, so
//  `Bundle.main` is Droppy's: Docked speaks the language Droppy speaks, and
//  English for any other.
//

import Foundation

enum Language {
    case english, french

    static let current: Language = {
        let preferred = Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("fr") ? .french : .english
    }()
}

/// One whole sentence, in English and in French. Values go in as
/// interpolations, so each language keeps its own word order.
func L(_ english: String, _ french: String) -> String {
    Language.current == .french ? french : english
}
