//
//  AppLibrary.swift
//  Dockfan
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The apps installed on the Mac, read once per sheet off the main actor.
@MainActor
final class AppCatalog: ObservableObject {
    @Published private(set) var apps: [AppEntry] = []
    @Published private(set) var loading = false

    func load() {
        guard apps.isEmpty, !loading else { return }
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let found = AppCatalog.scan()
            DispatchQueue.main.async { MainActor.assumeIsolated { self.apps = found; self.loading = false } }
        }
    }

    private nonisolated static func scan() -> [AppEntry] {
        let fm = FileManager.default
        let roots = ["/Applications", fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
                     "/System/Applications", "/System/Applications/Utilities"]
        var seen = Set<String>(), found: [AppEntry] = []
        func scan(_ folder: URL, depth: Int) {
            guard let urls = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                                                         options: [.skipsHiddenFiles]) else { return }
            for url in urls {
                if url.pathExtension.lowercased() == "app" {
                    if let entry = AppEntry(url: url), seen.insert(entry.path).inserted { found.append(entry) }
                } else if depth > 0, (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    scan(url, depth: depth - 1)
                }
            }
        }
        for root in roots { scan(URL(fileURLWithPath: root), depth: 1) }
        return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

struct AppLibrary: View {
    let existing: [AppEntry]
    let add: ([AppEntry]) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var catalog = AppCatalog()
    @State private var search = ""
    @State private var selected: [String] = []
    @FocusState private var searchFocused: Bool

    private var existingPaths: Set<String> { Set(existing.map(\.path)) }
    private var filtered: [AppEntry] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return catalog.apps.filter { query.isEmpty || $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Brand.hairline)
            ScrollView {
                if catalog.loading {
                    ProgressView().controlSize(.small).frame(maxWidth: .infinity).padding(.top, 120)
                } else if filtered.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").font(.system(size: 22, weight: .light))
                        Text(L("No app matches “\(search)”", "Aucune app ne correspond à « \(search) »")).font(.system(size: 12.5))
                    }
                    .foregroundStyle(Brand.secondary).frame(maxWidth: .infinity).padding(.top, 110)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(filtered) { app in tile(app) }
                    }
                    .padding(18)
                }
            }
            Divider().overlay(Brand.hairline)
            footer
        }
        .frame(width: 660, height: 580)
        .background(Brand.surface)
        .environment(\.colorScheme, .dark)
        .onAppear { searchFocused = true; catalog.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Add apps", "Ajouter des apps")).font(.system(size: 18, weight: .semibold)).foregroundStyle(Brand.text)
                    Text(L("They join the group in the order you pick them.", "Elles rejoignent le groupe dans l’ordre où vous les choisissez."))
                        .font(.system(size: 12)).foregroundStyle(Brand.secondary)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Brand.tertiary)
                TextField(L("Search apps", "Rechercher une app"), text: $search).textFieldStyle(.plain).focused($searchFocused)
                    .foregroundStyle(Brand.text)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(Brand.tertiary)
                }
            }
            .padding(.horizontal, 11).frame(height: 34)
            .glassCard(radius: 9)
        }
        .padding(20)
    }

    private func tile(_ app: AppEntry) -> some View {
        let added = existingPaths.contains(app.path)
        let order = selected.firstIndex(of: app.path)
        return Button {
            if let order { selected.remove(at: order) } else { selected.append(app.path) }
        } label: {
            VStack(spacing: 8) {
                Image(nsImage: app.icon).resizable().interpolation(.high).frame(width: 42, height: 42)
                Text(app.name).font(.system(size: 10.5, weight: .medium)).lineLimit(2)
                    .multilineTextAlignment(.center).foregroundStyle(Brand.text)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity).frame(height: 98)
            .glassCard(selected: order != nil)
            .overlay(alignment: .topTrailing) {
                if let order {
                    Text("\(order + 1)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 18, height: 18).background(Circle().fill(Brand.emberGradient)).padding(6)
                } else if added {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Brand.secondary).padding(6)
                }
            }
            .opacity(added ? 0.38 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(added)
        .help(added ? L("\(app.name) is already in the group", "\(app.name) est déjà dans le groupe") : app.name)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(L("Choose in Finder…", "Choisir dans le Finder…"), action: chooseInFinder).buttonStyle(QuietButtonStyle())
            Spacer()
            Button(L("Cancel", "Annuler")) { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
            Button {
                let byPath = Dictionary(catalog.apps.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
                add(selected.compactMap { byPath[$0] })
                dismiss()
            } label: {
                Text(selected.isEmpty ? L("Add", "Ajouter") : selected.count == 1 ? L("Add 1 app", "Ajouter 1 app") : L("Add \(selected.count) apps", "Ajouter \(selected.count) apps"))
            }
            .buttonStyle(EmberButtonStyle()).frame(width: 150)
            .disabled(selected.isEmpty).keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private func chooseInFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = L("Add", "Ajouter")
        guard panel.runModal() == .OK else { return }
        add(panel.urls.compactMap(AppEntry.init(url:)))
        dismiss()
    }
}
