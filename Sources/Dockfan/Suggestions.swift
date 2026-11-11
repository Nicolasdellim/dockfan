//
//  Suggestions.swift
//  Dockfan
//
//  Ready-made groups from the apps already on the Mac: the Adobe suite, the
//  Office apps, the browsers. Only the ones the Mac has two or more apps of.
//

import AppKit
import Foundation

struct GroupSuggestion: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let symbol: String
    let apps: [AppEntry]
}

enum Suggestions {
    private struct Recipe {
        let name: String
        let symbol: String
        let matches: @Sendable (AppEntry) -> Bool
    }

    private static let browsers: Set<String> = [
        "com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "company.thebrowser.Browser",
        "com.microsoft.edgemac", "com.brave.Browser", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
        "app.zen-browser.zen", "com.openai.atlas", "ai.perplexity.comet",
    ]
    private static let office: Set<String> = [
        "com.microsoft.Word", "com.microsoft.Excel", "com.microsoft.Powerpoint", "com.microsoft.Outlook",
        "com.microsoft.onenote.mac", "com.microsoft.teams2",
    ]
    private static let iwork: Set<String> = ["com.apple.iWork.Pages", "com.apple.iWork.Numbers", "com.apple.iWork.Keynote"]
    private static let utilities: Set<String> = [
        "com.apple.ActivityMonitor", "com.apple.Terminal", "com.apple.DiskUtility", "com.apple.SystemProfiler",
        "com.apple.Console", "com.apple.ScreenSharing", "com.apple.keychainaccess",
    ]

    private static let recipes: [Recipe] = [
        Recipe(name: "Adobe", symbol: "paintbrush.pointed") { app in
            guard let id = app.bundleIdentifier?.lowercased(), id.hasPrefix("com.adobe.") else { return false }
            // The suite's apps, not its installers, updaters and helpers.
            return !["installer", "uninstall", "update", "creative cloud", "helper", "acrobat updater"]
                .contains { app.name.lowercased().contains($0) }
        },
        Recipe(name: "Microsoft Office", symbol: "doc.text") { office.contains($0.bundleIdentifier ?? "") },
        Recipe(name: L("Browsers", "Navigateurs"), symbol: "globe") { browsers.contains($0.bundleIdentifier ?? "") },
        Recipe(name: L("Apple iWork", "Bureautique Apple"), symbol: "doc.richtext") { iwork.contains($0.bundleIdentifier ?? "") },
        Recipe(name: L("Utilities", "Utilitaires"), symbol: "wrench.and.screwdriver") { utilities.contains($0.bundleIdentifier ?? "") },
    ]

    /// The suggestions the installed apps allow, skipping any whose name a
    /// group already uses.
    static func make(from installed: [AppEntry], excluding names: Set<String>) -> [GroupSuggestion] {
        recipes.compactMap { recipe in
            guard !names.contains(recipe.name.lowercased()) else { return nil }
            let apps = installed.filter(recipe.matches)
            return apps.count >= 2 ? GroupSuggestion(name: recipe.name, symbol: recipe.symbol, apps: Array(apps.prefix(12))) : nil
        }
    }
}
