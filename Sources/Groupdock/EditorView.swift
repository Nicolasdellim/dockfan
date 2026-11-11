//
//  EditorView.swift
//  Groupdock
//
//  Three panels, as in the stand-alone GroupDock: the groups, a live
//  preview of the stack, and an inspector. Edits save as they happen.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum Style {
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let edge = Color.primary.opacity(0.08)
    static let radius: CGFloat = 14
}

struct EditorView: View {
    @ObservedObject var store: GroupStore

    var body: some View {
        HStack(spacing: 8) {
            Sidebar(store: store).frame(width: 220)
            if let group = store.selectedGroup {
                GroupEditor(store: store, group: group).id(group.id)
            } else {
                emptyState
            }
        }
        .padding(8)
        .padding(.top, 20)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 980, minHeight: 640)
        .alert("GroupDock", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up").font(.system(size: 40, weight: .light)).foregroundStyle(.secondary)
            Text("Aucun groupe").font(.title3.weight(.semibold))
            Text("Réunissez plusieurs apps dans une pile du Dock qui se déplie en éventail.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 320)
            Button("Créer un groupe", action: store.addGroup).buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!store.loaded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.panel, in: RoundedRectangle(cornerRadius: Style.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Style.radius, style: .continuous).strokeBorder(Style.edge))
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @ObservedObject var store: GroupStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text("GroupDock").font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 20)

            HStack {
                Text("Groupes").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(store.groups.count)").font(.system(size: 11)).foregroundStyle(.tertiary).monospacedDigit()
            }.padding(.horizontal, 18).padding(.bottom, 6)

            List(selection: $store.selection) {
                ForEach(store.groups) { group in
                    row(group).tag(group.id)
                        .contextMenu {
                            if store.inDock.contains(group.id) {
                                Button("Retirer du Dock") { store.removeFromDock(group) }
                            } else {
                                Button("Ajouter au Dock") { store.applyToDock(group) }.disabled(group.apps.isEmpty)
                            }
                            Button("Afficher dans le Finder") { store.revealInFinder(group) }
                            Divider()
                            Button("Supprimer le groupe", role: .destructive) { store.delete(group) }
                        }
                }
                .onMove(perform: store.moveGroups)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider().padding(.horizontal, 12)
            Button(action: store.addGroup) {
                Label("Nouveau groupe", systemImage: "plus").frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 13)
            .disabled(!store.loaded).keyboardShortcut("n")
        }
        .frame(maxHeight: .infinity)
        .background(Style.panel, in: RoundedRectangle(cornerRadius: Style.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Style.radius, style: .continuous).strokeBorder(Style.edge))
    }

    private func row(_ group: DockGroup) -> some View {
        HStack(spacing: 10) {
            PileIcon(apps: group.apps, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                Text(group.apps.count == 1 ? "1 app" : "\(group.apps.count) apps")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if store.pendingDock.contains(group.id) {
                Circle().fill(.orange).frame(width: 6, height: 6).help("Modifications à appliquer au Dock")
            } else if store.inDock.contains(group.id) {
                Image(systemName: "dock.rectangle").font(.system(size: 11)).foregroundStyle(.secondary).help("Dans le Dock")
            }
        }
        .padding(.vertical, 4)
    }
}

/// The closed stack, small: the first apps piled on each other.
struct PileIcon: View {
    let apps: [AppEntry]
    let size: CGFloat

    var body: some View {
        ZStack {
            if apps.isEmpty {
                Image(nsImage: NSWorkspace.shared.icon(for: .folder)).resizable()
            } else {
                ForEach(Array(apps.prefix(3).enumerated().reversed()), id: \.element.id) { index, app in
                    Image(nsImage: app.icon).resizable()
                        .scaleEffect(1 - CGFloat(index) * 0.08)
                        .offset(y: CGFloat(-index) * size * 0.07)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Group editor

private enum InspectorTab: String, CaseIterable, Identifiable {
    case apps = "Apps", appearance = "Apparence"
    var id: String { rawValue }
}

private struct GroupEditor: View {
    @ObservedObject var store: GroupStore
    @State private var group: DockGroup
    @State private var tab: InspectorTab = .apps
    @State private var expanded = true
    @State private var showingLibrary = false
    @State private var dropTargeted = false
    @State private var confirmingDelete = false

    init(store: GroupStore, group: DockGroup) {
        self.store = store
        _group = State(initialValue: group)
    }

    private var inDock: Bool { store.inDock.contains(group.id) }
    private var pending: Bool { store.pendingDock.contains(group.id) }

    var body: some View {
        HStack(spacing: 8) {
            previewPanel
            inspector.frame(width: 320)
        }
        .onChange(of: group) { _, new in store.update(new) }
        .sheet(isPresented: $showingLibrary) {
            AppLibrary(existing: group.apps) { append($0) }
        }
        .confirmationDialog("Supprimer « \(group.name) » ?", isPresented: $confirmingDelete) {
            Button("Supprimer le groupe", role: .destructive) { store.delete(group) }
        } message: {
            Text(inDock ? "La pile sera retirée du Dock. Vos applications ne sont pas touchées."
                        : "Vos applications ne sont pas touchées.")
        }
    }

    // MARK: Preview

    private var previewPanel: some View {
        ZStack(alignment: .top) {
            StackPreview(group: group, expanded: $expanded)
            HStack {
                Text(group.name.isEmpty ? "Sans nom" : group.name)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button { replay() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 30, height: 30).background(Circle().fill(.black.opacity(0.25)))
                }
                .buttonStyle(.plain).help("Rejouer l’animation")
            }
            .padding(16)
            if group.apps.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "plus.app").font(.system(size: 30, weight: .light))
                    Text("Ajoutez des apps pour voir la pile").font(.callout)
                }
                .foregroundStyle(.white.opacity(0.85)).frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: receive)
    }

    private func replay() {
        expanded = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { expanded = true }
    }

    // MARK: Inspector

    private var inspector: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                PileIcon(apps: group.displayedApps, size: 32)
                TextField("Nom du groupe", text: $group.name)
                    .textFieldStyle(.plain).font(.system(size: 15, weight: .semibold))
                Image(systemName: "pencil").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

            Picker("", selection: $tab) {
                ForEach(InspectorTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().padding(.horizontal, 16).padding(.bottom, 12)

            Divider()
            Group {
                switch tab {
                case .apps: appsTab
                case .appearance: ScrollView { appearanceTab.padding(16) }
                }
            }
            .frame(maxHeight: .infinity)
            Divider()
            dockBar.padding(14)
        }
        .background(Style.panel, in: RoundedRectangle(cornerRadius: Style.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Style.radius, style: .continuous).strokeBorder(Style.edge))
    }

    private var appsTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text(group.apps.count == 1 ? "1 application" : "\(group.apps.count) applications")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button { showingLibrary = true } label: { Image(systemName: "plus") }
                    .controlSize(.small).help("Ajouter des applications")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if group.apps.isEmpty {
                dropZone.padding(16)
                Spacer(minLength: 0)
            } else {
                List {
                    ForEach(group.apps) { app in
                        AppRow(app: app, label: group.label(for: app), first: app.id == group.displayedApps.first?.id) {
                            group.apps.removeAll { $0.id == app.id }
                        }
                    }
                    .onMove { group.apps.move(fromOffsets: $0, toOffset: $1) }
                    .moveDisabled(group.order == .name)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                Text(group.order == .name
                     ? "Classées par nom. Passez à l’ordre personnalisé dans Apparence pour les déplacer."
                     : "Glissez les lignes pour changer l’ordre. La première se place contre le Dock.")
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: receive)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: 2).padding(6).allowsHitTesting(false)
            }
        }
    }

    private var dropZone: some View {
        Button { showingLibrary = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.app").font(.system(size: 24, weight: .light))
                Text("Ajouter ou glisser des apps").font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 40)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            section("Ouverture") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(StackPresentation.allCases) { option in
                        let on = group.presentation == option
                        Button { group.presentation = option } label: {
                            VStack(spacing: 7) {
                                Image(systemName: option.symbol).font(.system(size: 17, weight: .light))
                                Text(option.title).font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(on ? Color.accentColor : .secondary)
                            .frame(maxWidth: .infinity).frame(height: 62)
                            .background(on ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(on ? Color.accentColor.opacity(0.5) : .clear))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            section("Icône dans le Dock") {
                Picker("", selection: $group.tileStyle) {
                    ForEach(TileStyle.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
                Text(group.tileStyle == .stack ? "La première app du groupe apparaît sur le dessus."
                                               : "Une icône de dossier, avec le nom du groupe.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            section("Ordre des apps") {
                Picker("", selection: $group.order) {
                    ForEach(StackOrder.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
            }
            section("Noms") {
                Toggle("Afficher l’extension .app", isOn: $group.showsExtension).toggleStyle(.switch).controlSize(.small)
                Text("Comme « Photoshop.app » au lieu de « Photoshop ».").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: Dock bar

    /// One place that says where the group stands with the Dock, and the one
    /// action that moves it forward.
    private var dockBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle().fill(pending ? Color.orange : inDock ? Color.green : Color.secondary.opacity(0.5)).frame(width: 7, height: 7)
                Text(pending ? "Modifications à appliquer" : inDock ? "Dans le Dock" : "Pas encore dans le Dock")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Menu {
                    Button("Afficher dans le Finder") { store.revealInFinder(group) }
                    if inDock { Button("Retirer du Dock") { store.removeFromDock(group) } }
                    Divider()
                    Button("Supprimer le groupe…", role: .destructive) { confirmingDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Plus d’actions")
            }
            if !inDock || pending {
                Button {
                    store.applyToDock(group)
                } label: {
                    Text(inDock ? "Appliquer au Dock" : "Ajouter au Dock").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(group.apps.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                Text("Le Dock se recharge une seconde.").font(.system(size: 10.5)).foregroundStyle(.tertiary)
            } else {
                Text("Les apps que vous ajoutez ou déplacez arrivent directement dans la pile.")
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Helpers

    private func append(_ apps: [AppEntry]) {
        for app in apps where !group.apps.contains(where: { $0.path == app.path }) { group.apps.append(app) }
    }

    private func receive(_ providers: [NSItemProvider]) -> Bool {
        let files = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        loadApps(from: files) { entries in
            MainActor.assumeIsolated { append(entries) }
        }
        return !files.isEmpty
    }
}

/// Item providers call back on a background queue. Their handlers are built
/// here, outside any actor, so they never inherit the main actor and trap;
/// the result reaches the main queue in one batch, in drop order.
private nonisolated func loadApps(from providers: [NSItemProvider], completion: @escaping @Sendable ([AppEntry]) -> Void) {
    final class Results: @unchecked Sendable {
        private let lock = NSLock()
        private var found: [Int: AppEntry] = [:]
        func set(_ entry: AppEntry, at index: Int) { lock.withLock { found[index] = entry } }
        var ordered: [AppEntry] { lock.withLock { found.keys.sorted().compactMap { found[$0] } } }
    }
    let group = DispatchGroup()
    let results = Results()
    for (index, provider) in providers.enumerated() {
        group.enter()
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url, let entry = AppEntry(url: url) { results.set(entry, at: index) }
            group.leave()
        }
    }
    group.notify(queue: .main) {
        completion(results.ordered)
    }
}

private struct AppRow: View {
    let app: AppEntry
    let label: String
    let first: Bool
    let remove: () -> Void
    @State private var hovered = false

    var body: some View {
        let available = app.resolvedURL != nil
        HStack(spacing: 9) {
            Image(nsImage: app.icon).resizable().frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 12, weight: .medium)).lineLimit(1)
                if !available {
                    Text("Introuvable").font(.system(size: 10)).foregroundStyle(.red.opacity(0.8))
                } else if first {
                    Text("Contre le Dock, sur le dessus de la pile").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .opacity(available ? 1 : 0.5)
            Spacer(minLength: 0)
            Button(action: remove) { Image(systemName: "minus.circle.fill") }
                .buttonStyle(.plain).foregroundStyle(.secondary).opacity(hovered ? 1 : 0).help("Retirer du groupe")
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }
}
