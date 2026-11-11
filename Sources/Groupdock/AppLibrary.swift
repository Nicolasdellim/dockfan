//
//  AppLibrary.swift
//  Groupdock
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppCatalog: ObservableObject {
    @Published private(set) var apps: [AppEntry] = []
    @Published private(set) var loading = false

    func load() {
        guard apps.isEmpty, !loading else { return }
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
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
            found.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async { self.apps = found; self.loading = false }
        }
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
        catalog.apps.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ajouter des applications").font(.title3.weight(.semibold))
                    Text("Elles s’ajoutent dans l’ordre où vous les cochez.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding([.horizontal, .top], 22).padding(.bottom, 14)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Rechercher", text: $search).textFieldStyle(.plain).focused($searchFocused)
            }
            .padding(9).background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 22).padding(.bottom, 14)
            Divider()
            ScrollView {
                if catalog.loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 90)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(filtered) { app in
                            let added = existingPaths.contains(app.path)
                            let order = selected.firstIndex(of: app.path)
                            Button {
                                if let order { selected.remove(at: order) } else { selected.append(app.path) }
                            } label: {
                                VStack(spacing: 7) {
                                    Image(nsImage: app.icon).resizable().frame(width: 40, height: 40)
                                    Text(app.name).font(.system(size: 10.5, weight: .medium)).lineLimit(2)
                                        .multilineTextAlignment(.center).foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity).frame(height: 96)
                                .background(order != nil ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.03),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(order != nil ? Color.accentColor.opacity(0.7) : .clear))
                                .overlay(alignment: .topTrailing) {
                                    if let order {
                                        Text("\(order + 1)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                            .frame(width: 17, height: 17).background(Circle().fill(Color.accentColor)).padding(6)
                                    } else if added {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.secondary).padding(6)
                                    }
                                }
                                .opacity(added ? 0.4 : 1)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).disabled(added).help(app.name)
                        }
                    }.padding(18)
                }
            }
            Divider()
            HStack {
                Button("Choisir dans le Finder…", action: chooseInFinder).buttonStyle(.link)
                Spacer()
                Button("Annuler") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(selected.isEmpty ? "Ajouter" : "Ajouter \(selected.count)") {
                    let byPath = Dictionary(catalog.apps.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
                    add(selected.compactMap { byPath[$0] }); dismiss()
                }
                .buttonStyle(.borderedProminent).disabled(selected.isEmpty).keyboardShortcut(.defaultAction)
            }.padding(18)
        }
        .frame(width: 640, height: 560)
        .onAppear { searchFocused = true; catalog.load() }
    }

    private func chooseInFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Ajouter"
        guard panel.runModal() == .OK else { return }
        add(panel.urls.compactMap(AppEntry.init(url:)))
        dismiss()
    }
}
