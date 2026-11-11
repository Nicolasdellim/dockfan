//
//  EditorView.swift
//  Dockfan
//
//  Three panels: the groups, a live preview of the stack, and an inspector.
//  Edits save as they happen; the inspector's last row is where the group
//  stands with the Dock and the one action that moves it forward.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @ObservedObject var store: GroupStore
    @StateObject private var catalog = AppCatalog()

    var body: some View {
        HStack(spacing: 10) {
            Sidebar(store: store, catalog: catalog).frame(width: 240)
            if let group = store.selectedGroup {
                GroupEditor(store: store, group: group).id(group.id)
            } else if store.loaded {
                Welcome(store: store, catalog: catalog)
            } else {
                Color.clear
            }
        }
        .padding(10)
        .background(WindowBackdrop())
        .overlay(alignment: .bottom) { NoticeBanner(notice: store.notice).padding(.bottom, 26) }
        .environment(\.colorScheme, .dark)
        .tint(Brand.ember)
        .frame(minWidth: 1040, minHeight: 680)
        .onAppear { catalog.load() }
        .alert("Dockfan", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}

/// The window's own background: the ink of the logo, warmed in one corner.
private struct WindowBackdrop: View {
    var body: some View {
        ZStack {
            Brand.ink
            RadialGradient(colors: [Brand.ember.opacity(0.10), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 700)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @ObservedObject var store: GroupStore
    @ObservedObject var catalog: AppCatalog
    @State private var dropTarget: UUID?

    private var suggestions: [GroupSuggestion] {
        Suggestions.make(from: catalog.apps, excluding: Set(store.groups.map { $0.name.lowercased() }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                DockfanLogo(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Dockfan").font(.system(size: 15, weight: .semibold)).foregroundStyle(Brand.text)
                    Text(L("Your apps, in a fan", "Vos apps, en éventail")).font(.system(size: 11)).foregroundStyle(Brand.tertiary)
                }
            }
            .padding(.horizontal, 16).padding(.top, 40).padding(.bottom, 22)

            HStack {
                SectionLabel(L("Groups", "Groupes"))
                Text("\(store.groups.count)").font(.system(size: 10, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(Brand.tertiary)
                Spacer()
                newGroupMenu
            }
            .padding(.horizontal, 16).padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.groups) { group in
                        row(group)
                            .onDrag { NSItemProvider(object: group.id.uuidString as NSString) }
                            .onDrop(of: [.text], delegate: GroupDropDelegate(target: group.id, store: store, hovered: $dropTarget))
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)
            if store.groups.isEmpty == false {
                hint.padding(12)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .glassPanel()
    }

    private var newGroupMenu: some View {
        Menu {
            Button { store.addGroup() } label: { Label(L("Empty group", "Groupe vide"), systemImage: "square.dashed") }
            if !suggestions.isEmpty {
                Section("Suggestions") {
                    ForEach(suggestions) { suggestion in
                        Button { store.addGroup(named: suggestion.name, apps: suggestion.apps) } label: {
                            Label("\(suggestion.name) · \(suggestion.apps.count) apps", systemImage: suggestion.symbol)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(Brand.text)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .overlay(Circle().strokeBorder(Brand.hairline))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help(L("New group", "Nouveau groupe"))
        .disabled(!store.loaded)
    }

    private func row(_ group: DockGroup) -> some View {
        let selected = store.selection == group.id
        return Button { store.selection = group.id } label: {
            HStack(spacing: 11) {
                DockTileIcon(group: group, image: store.image(for: group), size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Brand.text).lineLimit(1)
                    Text(group.apps.count == 1 ? "1 app" : "\(group.apps.count) apps")
                        .font(.system(size: 11)).foregroundStyle(Brand.secondary)
                }
                Spacer(minLength: 0)
                StatusDot(state: store.state(of: group))
            }
            .padding(.horizontal, 9).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.085) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(selected ? Brand.highlight : dropTarget == group.id ? Brand.ember.opacity(0.6) : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            store.selection = group.id
            DispatchQueue.main.async { store.renaming = group.id }
        })
        .contextMenu { GroupActions(store: store, group: group) }
        .help(L("Double-click to rename", "Double-cliquez pour renommer"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var hint: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lightbulb").font(.system(size: 11)).foregroundStyle(Brand.ember)
            Text(L("Double-click a group to rename it. Drag to reorder. Right-click for more.", "Double-cliquez un groupe pour le renommer. Glissez pour réordonner. Clic droit pour le reste."))
                .font(.system(size: 10.5)).foregroundStyle(Brand.tertiary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

private struct GroupDropDelegate: DropDelegate {
    let target: UUID
    let store: GroupStore
    @Binding var hovered: UUID?

    func dropEntered(info: DropInfo) { hovered = target }
    func dropExited(info: DropInfo) { if hovered == target { hovered = nil } }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        hovered = nil
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        let target = target, store = store
        _ = provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let raw = value as? String, let id = UUID(uuidString: raw) else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let from = store.groups.firstIndex(where: { $0.id == id }),
                          let to = store.groups.firstIndex(where: { $0.id == target }), from != to else { return }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        store.moveGroups(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
                    }
                }
            }
        }
        return true
    }
}

/// The actions every group offers, in its context menu and its “…” menu.
private struct GroupActions: View {
    @ObservedObject var store: GroupStore
    let group: DockGroup

    var body: some View {
        Button(L("Rename…", "Renommer…")) {
            store.selection = group.id
            DispatchQueue.main.async { store.renaming = group.id }
        }
        Divider()
        if store.inDock.contains(group.id) {
            if store.pendingDock.contains(group.id) {
                Button(L("Apply to Dock", "Appliquer au Dock")) { store.applyToDock(group) }
            }
            Button(L("Remove from Dock", "Retirer du Dock")) { store.removeFromDock(group) }
        } else {
            Button(L("Add to Dock", "Ajouter au Dock")) { store.applyToDock(group) }.disabled(group.apps.isEmpty)
        }
        Button(L("Show in Finder", "Afficher dans le Finder")) { store.revealInFinder(group) }
        Button(L("Duplicate", "Dupliquer")) { store.duplicate(group) }
        Divider()
        Button(L("Delete group", "Supprimer le groupe"), role: .destructive) { store.delete(group) }
    }
}

enum DockState { case notInDock, inDock, pending, working }

extension GroupStore {
    func state(of group: DockGroup) -> DockState {
        if working.contains(group.id) { return .working }
        if pendingDock.contains(group.id) { return .pending }
        return inDock.contains(group.id) ? .inDock : .notInDock
    }
}

private struct StatusDot: View {
    let state: DockState
    var body: some View {
        switch state {
        case .working: ProgressView().controlSize(.mini)
        case .pending: dot(Brand.ember).help(L("Changes to apply to the Dock", "Modifications à appliquer au Dock"))
        case .inDock: dot(Brand.success).help(L("In the Dock", "Dans le Dock"))
        case .notInDock: EmptyView()
        }
    }
    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 7, height: 7).shadow(color: color.opacity(0.7), radius: 3)
    }
}

// MARK: - Welcome

/// Shown until the first group exists.
private struct Welcome: View {
    @ObservedObject var store: GroupStore
    @ObservedObject var catalog: AppCatalog

    private var suggestions: [GroupSuggestion] {
        Suggestions.make(from: catalog.apps, excluding: Set(store.groups.map { $0.name.lowercased() }))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            DockfanLogo(size: 116)
                .shadow(color: Brand.ember.opacity(0.25), radius: 40, y: 10)
                .padding(.bottom, 26)
            Text(L("Welcome to Dockfan", "Bienvenue dans Dockfan")).font(.system(size: 26, weight: .semibold)).foregroundStyle(Brand.text)
            Text(L("Keep several apps in one stack of the Dock.\nOne click and they spread out in a fan.", "Rangez plusieurs apps dans une seule pile du Dock.\nUn clic, et elles se déploient en éventail."))
                .font(.system(size: 14)).foregroundStyle(Brand.secondary).multilineTextAlignment(.center)
                .lineSpacing(3).padding(.top, 10)

            HStack(spacing: 10) {
                step(1, "Créez un groupe", "square.stack.3d.up")
                step(2, "Choisissez ses apps", "app.badge.checkmark")
                step(3, "Ajoutez-le au Dock", "dock.rectangle")
            }
            .padding(.top, 30)

            Button(L("Create a group", "Créer un groupe")) { store.addGroup() }
                .buttonStyle(EmberButtonStyle()).frame(width: 240).padding(.top, 30)
                .keyboardShortcut(.defaultAction)

            if !suggestions.isEmpty {
                VStack(spacing: 10) {
                    SectionLabel(L("Or start from a suggestion", "Ou partez d’une suggestion"))
                    HStack(spacing: 8) {
                        ForEach(suggestions) { suggestion in
                            Button { store.addGroup(named: suggestion.name, apps: suggestion.apps) } label: {
                                HStack(spacing: 8) {
                                    PileIcon(apps: suggestion.apps, size: 22)
                                    Text(suggestion.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Brand.text)
                                    Text("\(suggestion.apps.count)").font(.system(size: 11)).foregroundStyle(Brand.tertiary)
                                }
                                .padding(.horizontal, 11).frame(height: 36)
                                .glassCard(radius: 18)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 34)
            }
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassPanel()
    }

    private func step(_ number: Int, _ title: String, _ symbol: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 18, weight: .light)).foregroundStyle(Brand.ember)
                .frame(width: 40, height: 40).background(Circle().fill(Brand.ember.opacity(0.1)))
            Text("\(number). \(title)").font(.system(size: 12, weight: .medium)).foregroundStyle(Brand.text)
        }
        .frame(width: 170, height: 104)
        .glassCard(radius: 14)
    }
}

// MARK: - Group editor

private struct GroupEditor: View {
    @ObservedObject var store: GroupStore
    @State private var group: DockGroup
    @State private var expanded = true
    @State private var showingLibrary = false
    @State private var confirmingDelete = false
    @State private var stageDropTargeted = false

    init(store: GroupStore, group: DockGroup) {
        self.store = store
        _group = State(initialValue: group)
    }

    private var state: DockState { store.state(of: group) }
    private var inDock: Bool { store.inDock.contains(group.id) }

    var body: some View {
        HStack(spacing: 10) {
            stage
            Inspector(store: store, group: $group, showingLibrary: $showingLibrary, confirmingDelete: $confirmingDelete,
                      receive: receive)
                .frame(width: 368)
        }
        .onChange(of: group) { _, new in store.update(new) }
        // Changes made elsewhere (a shuffle, a picture, a menu) come back here.
        .onReceive(store.$document) { document in
            if let saved = document.groups.first(where: { $0.id == group.id }), saved != group { group = saved }
        }
        .sheet(isPresented: $showingLibrary) {
            AppLibrary(existing: group.apps) { append($0) }
        }
        .confirmationDialog(L("Delete “\(group.name)”?", "Supprimer « \(group.name) » ?"), isPresented: $confirmingDelete) {
            Button(L("Delete group", "Supprimer le groupe"), role: .destructive) { store.delete(group) }
        } message: {
            Text(inDock ? L("Its tile leaves the Dock. Your apps are not touched.", "Sa tuile est retirée du Dock. Vos apps ne sont pas touchées.")
                        : L("Your apps are not touched.", "Vos apps ne sont pas touchées."))
        }
    }

    // MARK: Stage

    private var stage: some View {
        ZStack(alignment: .top) {
            StackPreview(group: group, image: store.image(for: group), expanded: $expanded)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Preview", "Aperçu")).font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(.white.opacity(0.45))
                    Text(group.folderName).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Label(group.mode.title, systemImage: "rectangle.stack")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.ember)
                }
                Spacer()
                StateChip(state: state)
                Button { replay() } label: { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(IconButtonStyle(size: 30)).help(L("Replay the animation", "Rejouer l’animation"))
                    .disabled(group.apps.isEmpty)
            }
            .padding(18)

            if group.apps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "plus.app").font(.system(size: 30, weight: .ultraLight)).foregroundStyle(.white.opacity(0.8))
                    Text(L("Add apps to “\(group.folderName)”", "Ajoutez des apps à « \(group.folderName) »")).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    Text(L("or drag them here from Finder", "ou glissez-les ici depuis le Finder")).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                    Button(L("Choose apps", "Choisir des apps")) { showingLibrary = true }.buttonStyle(EmberButtonStyle()).frame(width: 180).padding(.top, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.bottom, 60)
            } else {
                Text(L("Click the tile to open or close it · settings on the right", "Cliquez sur la tuile pour ouvrir ou fermer · réglages à droite"))
                    .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 6)
            }
        }
        .overlay {
            if stageDropTargeted {
                RoundedRectangle(cornerRadius: Brand.radius, style: .continuous)
                    .strokeBorder(Brand.ember, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .background(Brand.ember.opacity(0.06), in: RoundedRectangle(cornerRadius: Brand.radius, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $stageDropTargeted, perform: receive)
    }

    private func replay() {
        expanded = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { expanded = true }
    }

    // MARK: Helpers

    private func append(_ apps: [AppEntry]) {
        let fresh = apps.filter { app in !group.apps.contains { $0.path == app.path } }
        guard !fresh.isEmpty else { return }
        group.apps.append(contentsOf: fresh)
        if !expanded { expanded = true }
    }

    private func receive(_ providers: [NSItemProvider]) -> Bool {
        let files = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        loadApps(from: files) { entries in
            MainActor.assumeIsolated { append(entries) }
        }
        return !files.isEmpty
    }
}

private struct StateChip: View {
    let state: DockState
    var body: some View {
        let (text, color): (String, Color) = switch state {
        case .working: (L("Updating…", "Mise à jour…"), .white.opacity(0.7))
        case .pending: (L("To apply", "À appliquer"), Brand.ember)
        case .inDock: (L("In the Dock", "Dans le Dock"), Brand.success)
        case .notInDock: (L("Not in the Dock", "Hors du Dock"), .white.opacity(0.55))
        }
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10).frame(height: 26)
        .background(Capsule().fill(.black.opacity(0.35)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
    }
}

// MARK: - Inspector

private struct Inspector: View {
    @ObservedObject var store: GroupStore
    @Binding var group: DockGroup
    @Binding var showingLibrary: Bool
    @Binding var confirmingDelete: Bool
    let receive: ([NSItemProvider]) -> Bool
    @State private var listDropTargeted = false
    @State private var choosingImage = false
    @State private var editingName = false
    @State private var draftName = ""
    @FocusState private var nameFocused: Bool

    private var state: DockState { store.state(of: group) }
    private var draftTaken: Bool { store.nameIsTaken(draftName, by: group.id) }

    var body: some View {
        VStack(spacing: 0) {
            header
            SegmentedTabs(selection: $store.inspectorTab).padding(.horizontal, 16).padding(.bottom, 12)
            Divider().overlay(Brand.hairline)
            Group {
                switch store.inspectorTab {
                case .apps: appsTab
                case .opening: ScrollView { displayTab.padding(16) }
                case .icon: ScrollView { iconTab.padding(16) }
                }
            }
            .frame(maxHeight: .infinity)
            Divider().overlay(Brand.hairline)
            dockBar.padding(16)
        }
        .glassPanel()
        .fileImporter(isPresented: $choosingImage, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result { store.importImage(from: url, for: group.id) }
        }
        .onChange(of: store.renaming) { _, id in
            // “Rename…” from a menu while this group is open edits it here.
            if id == group.id { startRenaming(); store.renaming = nil }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                DockTileIcon(group: group, image: store.image(for: group), size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    if editingName {
                        TextField(L("Group name", "Nom du groupe"), text: $draftName)
                            .textFieldStyle(.plain).font(.system(size: 16, weight: .semibold)).foregroundStyle(Brand.text)
                            .padding(.horizontal, 7).frame(height: 28)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.black.opacity(0.35)))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(draftTaken ? Brand.ember : Brand.ember.opacity(0.6)))
                            .focused($nameFocused)
                            .onSubmit(commitName)
                            .onExitCommand { editingName = false }
                    } else {
                        Button(action: startRenaming) {
                            HStack(spacing: 6) {
                                Text(group.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Brand.text).lineLimit(1)
                                Image(systemName: "pencil").font(.system(size: 11, weight: .semibold)).foregroundStyle(Brand.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(L("Rename", "Renommer"))
                    }
                    Text(summary).font(.system(size: 11)).foregroundStyle(Brand.tertiary)
                }
                Spacer(minLength: 0)
                if editingName {
                    Button(L("OK", "OK"), action: commitName).buttonStyle(QuietButtonStyle(compact: true)).disabled(draftTaken)
                } else {
                    Menu { GroupActions(store: store, group: group) } label: {
                        Image(systemName: "ellipsis").font(.system(size: 12, weight: .bold)).foregroundStyle(Brand.text)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                            .overlay(Circle().strokeBorder(Brand.hairline))
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help(L("Group actions", "Actions du groupe"))
                }
            }
            if editingName && draftTaken {
                Label(L("Another group already has this name.", "Un autre groupe porte déjà ce nom."), systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundStyle(Brand.ember)
            }
        }
        .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 14)
    }

    private func startRenaming() {
        draftName = group.name
        editingName = true
        DispatchQueue.main.async { nameFocused = true }
    }

    private func commitName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !draftTaken else { return }
        if trimmed != group.name {
            group.name = trimmed
            store.show("pencil", store.inDock.contains(group.id) ? L("Renamed. Apply to update the Dock.", "Renommé. Appliquez pour mettre le Dock à jour.")
                                                              : L("Renamed “\(trimmed)”", "Renommé « \(trimmed) »"))
        }
        editingName = false
    }

    private var summary: String {
        let count = group.apps.count == 1 ? "1 app" : "\(group.apps.count) apps"
        return "\(group.mode.title) · \(count)"
    }

    // MARK: Apps

    private var appsTab: some View {
        VStack(spacing: 0) {
            if group.apps.isEmpty {
                emptyApps.padding(16)
                Spacer(minLength: 0)
            } else {
                List {
                    ForEach(Array(group.displayedApps.enumerated()), id: \.element.id) { index, app in
                        AppRow(app: app, label: group.label(for: app), note: index == 0 ? firstNote : nil, movable: group.order == .custom) {
                            withAnimation(.easeInOut(duration: 0.18)) { group.apps.removeAll { $0.id == app.id } }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    }
                    .onMove { group.apps.move(fromOffsets: $0, toOffset: $1) }
                    .moveDisabled(group.order == .name)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Button { showingLibrary = true } label: {
                            Label(L("Add apps", "Ajouter des apps"), systemImage: "plus").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(QuietButtonStyle())
                    }
                    PillPicker(options: StackOrder.allCases.map { ($0, $0.title) }, selection: $group.order)
                    Text(group.order == .name
                         ? L("Sorted by name. Choose Custom to drag them.", "Classées par nom. Choisissez Personnalisé pour les glisser.")
                         : L("Drag to reorder. The first one opens closest to the Dock.", "Glissez pour réordonner. La première s’ouvre au plus près du Dock."))
                        .font(.system(size: 10.5)).foregroundStyle(Brand.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $listDropTargeted, perform: receive)
        .overlay {
            if listDropTargeted {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Brand.ember, lineWidth: 2).padding(6).allowsHitTesting(false)
            }
        }
    }

    private var firstNote: String { L("First, closest to the Dock", "En premier, au plus près du Dock") }

    private var emptyApps: some View {
        Button { showingLibrary = true } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus.app").font(.system(size: 26, weight: .ultraLight)).foregroundStyle(Brand.ember)
                Text(L("Add apps", "Ajouter des apps")).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Brand.text)
                Text(L("or drag them from Finder", "ou glissez-les depuis le Finder")).font(.system(size: 11)).foregroundStyle(Brand.tertiary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.ember.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Brand.ember.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Fan

    private var native: Bool { group.mode == .stack }

    private var displayTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            if native {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill").font(.system(size: 13)).foregroundStyle(Brand.ember)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("This group uses macOS’s own fan, which can’t be customised. Switch to Dockfan’s fan to use the settings below.",
                               "Ce groupe utilise l’éventail de macOS, qui ne se personnalise pas. Passez à l’éventail Dockfan pour utiliser les réglages ci-dessous."))
                            .font(.system(size: 11)).foregroundStyle(Brand.text).fixedSize(horizontal: false, vertical: true)
                        Button { withAnimation { group.mode = .folder } } label: { Label(L("Use Dockfan’s fan", "Utiliser l’éventail Dockfan"), systemImage: "wand.and.stars") }
                            .buttonStyle(QuietButtonStyle(compact: true))
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.ember.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Brand.ember.opacity(0.35)))
            }

            VStack(alignment: .leading, spacing: 12) {
                PresetStrip(style: $group.panel) { store.shuffleOpening(of: group) }

                Card(title: L("Icons", "Icônes"), symbol: "app.dashed") {
                    VStack(alignment: .leading, spacing: 12) {
                        SliderRow(title: L("Size", "Taille"), value: $group.panel.iconSize, range: 28...96, step: 2,
                                  display: "\(Int(group.panel.iconSize)) pt")
                        SliderRow(title: L("Distance between icons", "Distance entre les icônes"), value: $group.panel.spacing, range: 0...32, step: 1,
                                  display: "\(Int(group.panel.spacing)) pt")
                        SliderRow(title: L("Curve", "Courbure"), value: $group.panel.curve, range: 0...1.6, step: 0.05,
                                  display: group.panel.curve < 0.05 ? L("Straight", "Droit") : "\(Int((group.panel.curve / 1.6 * 100).rounded())) %")
                        labeled(L("Bends", "Penche")) {
                            PillPicker(options: [(true, L("To the right", "Vers la droite")), (false, L("To the left", "Vers la gauche"))], selection: $group.panel.bendsRight)
                        }
                        .disabled(group.panel.curve < 0.05).opacity(group.panel.curve < 0.05 ? 0.4 : 1)
                        Toggle(isOn: $group.panel.shadows) { toggleLabel(L("Shadows", "Ombres"), L("A soft shadow under each icon", "Une ombre douce sous chaque icône")) }
                            .toggleStyle(.switch).controlSize(.small)
                    }
                }

                Card(title: L("Names", "Noms"), symbol: "textformat") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $group.panel.showsLabels) {
                            toggleLabel(L("Show the names", "Afficher les noms"), L("Off: just the icons", "Désactivé : seulement les icônes"))
                        }
                        .toggleStyle(.switch).controlSize(.small)
                        if group.panel.showsLabels {
                            labeled(L("Style", "Style")) { PillPicker(options: FanLabels.allCases.map { ($0, $0.title) }, selection: $group.panel.labels) }
                            labeled(L("Side", "Côté")) {
                                PillPicker(options: [(true, L("Left", "À gauche")), (false, L("Right", "À droite"))], selection: $group.panel.labelsLeft)
                            }
                            SliderRow(title: L("Text size", "Taille du texte"), value: $group.panel.labelSize, range: 10...18, step: 0.5,
                                      display: "\(String(format: "%g", group.panel.labelSize)) pt")
                        }
                        if group.panel.showsLabels && group.panel.labels != .dark || group.panel.hover == .glow {
                            Divider().overlay(Brand.hairline)
                            ColorRow(style: $group.panel)
                        }
                    }
                }

                Card(title: L("Motion", "Mouvement"), symbol: "sparkles") {
                    VStack(alignment: .leading, spacing: 12) {
                        labeled(L("Opening", "Ouverture")) { PillPicker(options: OpenAnimation.allCases.map { ($0, $0.title) }, selection: $group.panel.opening) }
                        SliderRow(title: L("One after the other", "Une icône après l’autre"), value: $group.panel.cascade, range: 0...0.08, step: 0.004,
                                  display: group.panel.cascade < 0.002 ? L("Together", "Ensemble") : "\(Int((group.panel.cascade * 1000).rounded())) ms")
                        labeled(L("On hover", "Au survol")) { PillPicker(options: HoverEffect.allCases.map { ($0, $0.title) }, selection: $group.panel.hover) }
                    }
                }
            }
            .disabled(native)
            .opacity(native ? 0.4 : 1)

            Card(title: L("Fan engine", "Moteur de l’éventail"), symbol: "gearshape") {
                VStack(spacing: 6) {
                    ForEach([GroupMode.folder, .stack]) { mode in
                        RendererRow(mode: mode, selected: group.mode == mode) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { group.mode = mode }
                        }
                    }
                    if native {
                        Toggle(isOn: $group.showsExtension) {
                            toggleLabel(L("Show the .app extension", "Afficher l’extension .app"), L("“Photoshop.app” instead of “Photoshop”", "« Photoshop.app » au lieu de « Photoshop »"))
                        }
                        .toggleStyle(.switch).controlSize(.small).padding(.top, 6)
                    }
                }
            }
        }
    }

    // MARK: Icon

    private var iconTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            iconHero
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(L("Style", "Style"))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(TileStyle.available(for: group.mode)) { style in
                        StyleTile(style: style, group: group, image: store.image(for: group),
                                  selected: group.effectiveTileStyle == style) {
                            if style == .image, group.iconImage == nil { choosingImage = true } else { group.tileStyle = style }
                        }
                    }
                }
            }
            switch group.effectiveTileStyle {
            case .appGrid:
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(L("Background", "Fond"))
                    FinishSwatches(selection: Binding(get: { group.iconFinish }, set: { group.iconFinish = $0 ?? .glass }), allowsNone: false)
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(L("Apps on the icon", "Apps sur l’icône"))
                    PillPicker(options: [(2, "2 × 2"), (3, "3 × 3")], selection: $group.iconGrid)
                    note(L("The first apps of the group, in its order.", "Les premières apps du groupe, dans son ordre."))
                }
            case .singleApp:
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(L("Which app", "Quelle app"))
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 8), count: 6), alignment: .leading, spacing: 8) {
                        ForEach(group.displayedApps) { app in
                            let chosen = group.singleApp?.id == app.id
                            Button { group.iconApp = app.id } label: {
                                Image(nsImage: app.icon).resizable().interpolation(.high).frame(width: 36, height: 36)
                                    .padding(4)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(chosen ? Brand.ember.opacity(0.18) : Color.white.opacity(0.04)))
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(chosen ? Brand.ember : Brand.hairline, lineWidth: chosen ? 1.5 : 1))
                            }
                            .buttonStyle(.plain).help(app.name)
                        }
                    }
                }
            case .image:
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(L("Picture", "Image"))
                    Button { choosingImage = true } label: {
                        Label(group.iconImage == nil ? L("Choose a picture…", "Choisir une image…") : L("Replace…", "Remplacer…"),
                              systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(QuietButtonStyle())
                    note(L("A photo, a logo, anything. It is cropped to the Dock’s rounded square.", "Une photo, un logo, ce que vous voulez. Elle est recadrée au carré arrondi du Dock."))
                }
            case .stack:
                note(L("The apps piled on each other, the first one on top: the Dock’s own look.", "Les apps empilées, la première au-dessus : le style natif du Dock."))
            case .folder:
                note(L("The macOS folder icon.", "L’icône de dossier de macOS."))
            }
        }
    }

    private var iconHero: some View {
        HStack(spacing: 16) {
            DockTileIcon(group: group, image: store.image(for: group), size: 84)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: group.iconFinish)
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Dock icon", "Icône du Dock")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Brand.text)
                Text(L("What the group looks like among your apps.", "L’allure du groupe parmi vos apps."))
                    .font(.system(size: 11)).foregroundStyle(Brand.tertiary).fixedSize(horizontal: false, vertical: true)
                Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.shuffleLook(of: group) } } label: {
                    Label(L("Shuffle", "Au hasard"), systemImage: "shuffle")
                }
                .buttonStyle(QuietButtonStyle(compact: true))
                .disabled(group.apps.isEmpty)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(radius: 16)
    }

    // MARK: Bits

    private func toggleLabel(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Brand.text)
            Text(subtitle).font(.system(size: 10.5)).foregroundStyle(Brand.tertiary)
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Brand.text)
            content()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 10.5)).foregroundStyle(Brand.tertiary).fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Dock bar

    /// Where the group stands with the Dock, and the one action that moves it.
    private var dockBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch inDockBarState {
            case .notInDock:
                Button {
                    store.applyToDock(group)
                } label: {
                    HStack(spacing: 8) {
                        if state == .working { ProgressView().controlSize(.small).tint(.white) }
                        Text(state == .working ? L("Adding…", "Ajout en cours…") : L("Add to Dock", "Ajouter au Dock"))
                    }
                }
                .buttonStyle(EmberButtonStyle())
                .disabled(group.apps.isEmpty || state == .working)
                .keyboardShortcut(.return, modifiers: .command)
                footnote(group.apps.isEmpty ? L("Add at least one app.", "Ajoutez au moins une app.")
                         : group.mode == .stack ? L("A stack beside the Trash. The Dock reloads for a second.", "Une pile près de la corbeille. Le Dock se recharge une seconde.")
                         : L("A tile among your apps. The Dock reloads for a second.", "Une tuile parmi vos apps. Le Dock se recharge une seconde."))
            case .pending:
                Button { store.applyToDock(group) } label: {
                    HStack(spacing: 8) {
                        if state == .working { ProgressView().controlSize(.small).tint(.white) }
                        Text(state == .working ? L("Updating…", "Mise à jour…") : L("Apply to Dock", "Appliquer au Dock"))
                    }
                }
                .buttonStyle(EmberButtonStyle())
                .disabled(state == .working || group.apps.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                footnote(L("The tile, its name and its icon change when the Dock reloads.", "La tuile, son nom et son icône changent quand le Dock se recharge."))
            case .inDock, .working:
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(Brand.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("In the Dock", "Dans le Dock")).font(.system(size: 13, weight: .semibold)).foregroundStyle(Brand.text)
                        Text(group.mode == .stack
                             ? L("Apps you add or move show up there right away.", "Les apps ajoutées ou déplacées y arrivent directement.")
                             : L("Every display setting applies right away.", "Chaque réglage d’affichage s’applique directement."))
                            .font(.system(size: 11)).foregroundStyle(Brand.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
                Button(L("Remove from Dock", "Retirer du Dock")) { store.removeFromDock(group) }.buttonStyle(QuietButtonStyle(compact: true))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inDockBarState: DockState {
        switch state {
        case .working: store.inDock.contains(group.id) ? .pending : .notInDock
        default: state
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text).font(.system(size: 10.5)).foregroundStyle(Brand.tertiary).frame(maxWidth: .infinity).multilineTextAlignment(.center)
    }
}

// MARK: - Inspector components


/// A rounded card holding a group of settings, with an optional title.
private struct Card<Content: View>: View {
    var title: String? = nil
    var symbol: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(spacing: 7) {
                    if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(Brand.ember) }
                    Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Brand.text)
                }
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}



/// Dockfan or macOS, as two radio rows.
private struct RendererRow: View {
    let mode: GroupMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    Circle().strokeBorder(selected ? Brand.ember : Brand.tertiary, lineWidth: 1.5).frame(width: 16, height: 16)
                    if selected { Circle().fill(Brand.ember).frame(width: 8, height: 8) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(mode == .folder ? L("Dockfan · made to measure", "Dockfan · sur mesure") : L("macOS · native", "macOS · natif"))
                            .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Brand.text)
                        if mode == .folder {
                            Text(L("Recommended", "Conseillé")).font(.system(size: 9, weight: .bold)).foregroundStyle(Brand.ember)
                                .padding(.horizontal, 6).frame(height: 16).background(Capsule().fill(Brand.ember.opacity(0.15)))
                        }
                    }
                    Text(mode.subtitle).font(.system(size: 10.5)).foregroundStyle(Brand.tertiary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(selected: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The presets as chips, each showing its colour, and a shuffle.
private struct PresetStrip: View {
    @Binding var style: PanelStyle
    let shuffle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L("Presets", "Préréglages")).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Brand.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button(action: shuffle) {
                        Label(L("Shuffle", "Au hasard"), systemImage: "shuffle").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Brand.ink).padding(.horizontal, 10).frame(height: 28)
                            .background(Capsule().fill(Brand.emberGradient))
                    }
                    .buttonStyle(.plain)
                    ForEach(LookPreset.all) { preset in
                        let sample = sampled(preset)
                        Button { withAnimation(.easeOut(duration: 0.2)) { preset.apply(&style) } } label: {
                            HStack(spacing: 6) {
                                Circle().fill(Self.dot(sample))
                                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.6))
                                    .frame(width: 12, height: 12)
                                Text(preset.title).font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.text)
                            }
                            .padding(.horizontal, 10).frame(height: 28)
                            .background(Capsule().fill(Color.white.opacity(matches(sample) ? 0.14 : 0.06)))
                            .overlay(Capsule().strokeBorder(matches(sample) ? Brand.ember.opacity(0.6) : Brand.hairline))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sampled(_ preset: LookPreset) -> PanelStyle {
        var copy = style
        preset.apply(&copy)
        return copy
    }

    private func matches(_ sample: PanelStyle) -> Bool { sample == style }

    private static func dot(_ sample: PanelStyle) -> Color {
        if !sample.showsLabels { return Color.white.opacity(0.25) }
        if sample.labels == .dark { return Color.black }
        return Color(nsColor: sample.tintColor ?? NSColor(white: 0.85, alpha: 1))
    }
}


/// Colour swatches, “none”, and a colour of one's own.
private struct ColorRow: View {
    @Binding var style: PanelStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Colour", "Couleur")).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Brand.text)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 7), count: 8), alignment: .leading, spacing: 7) {
                swatch(nil)
                ForEach(Finish.allCases) { swatch($0) }
                ColorPicker("", selection: custom, supportsOpacity: false)
                    .labelsHidden().frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(style.customTint != nil ? Brand.ember : .clear, lineWidth: 2).padding(-3).allowsHitTesting(false))
                    .help(L("A colour of your own", "Votre propre couleur"))
            }
        }
    }

    private var custom: Binding<Color> {
        Binding(get: { Color(nsColor: style.tintColor ?? .white) },
                set: { style.customTint = NSColor($0).hexString })
    }

    private func swatch(_ finish: Finish?) -> some View {
        let selected = style.customTint == nil && style.tint == finish
        return Button { withAnimation(.easeOut(duration: 0.15)) { style.customTint = nil; style.tint = finish } } label: {
            ZStack {
                if let finish {
                    Circle().fill(LinearGradient(colors: [Color(nsColor: finish.colors.0), Color(nsColor: finish.colors.1)], startPoint: .top, endPoint: .bottom))
                } else {
                    Circle().fill(.white.opacity(0.08))
                    Image(systemName: "circle.slash").font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.secondary)
                }
                Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.75)
            }
            .frame(width: 24, height: 24)
            .overlay(Circle().strokeBorder(selected ? Brand.ember : .clear, lineWidth: 2).padding(-3))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(finish?.title ?? L("No colour", "Sans couleur"))
    }
}



/// One icon style, drawn with the group's own apps.
private struct StyleTile: View {
    let style: TileStyle
    let group: DockGroup
    let image: NSImage?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                preview.frame(width: 40, height: 40)
                Text(style.title).font(.system(size: 10.5, weight: .medium)).foregroundStyle(Brand.text).lineLimit(1)
            }
            .frame(maxWidth: .infinity).frame(height: 84)
            .glassCard(selected: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var shown: DockGroup {
        var copy = group
        copy.tileStyle = style
        return copy
    }

    @ViewBuilder private var preview: some View {
        if style == .image && image == nil {
            Image(systemName: "photo.badge.plus").font(.system(size: 20, weight: .light)).foregroundStyle(Brand.secondary)
        } else {
            DockTileIcon(group: shown, image: image, size: 40)
        }
    }
}

/// The finishes as round swatches; with `allowsNone`, a first “clear” one.
private struct FinishSwatches: View {
    @Binding var selection: Finish?
    let allowsNone: Bool

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 9), count: 8), alignment: .leading, spacing: 9) {
            if allowsNone { swatch(nil) }
            ForEach(Finish.allCases) { swatch($0) }
        }
    }

    private func swatch(_ finish: Finish?) -> some View {
        let selected = selection == finish
        return Button { withAnimation(.easeOut(duration: 0.15)) { selection = finish } } label: {
            ZStack {
                if let finish {
                    Circle().fill(LinearGradient(colors: [Color(nsColor: finish.colors.0), Color(nsColor: finish.colors.1)],
                                                 startPoint: .top, endPoint: .bottom))
                } else {
                    Circle().fill(.white.opacity(0.08))
                    Image(systemName: "circle.slash").font(.system(size: 12, weight: .medium)).foregroundStyle(Brand.secondary)
                }
                Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.75)
            }
            .frame(width: 26, height: 26)
            .padding(3)
            .overlay(Circle().strokeBorder(selected ? Brand.ember : .clear, lineWidth: 2))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(finish?.title ?? L("No tint", "Sans teinte"))
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let display: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Brand.text)
                Spacer()
                Text(display).font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundStyle(Brand.text)
                    .padding(.horizontal, 8).frame(height: 22)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            Slider(value: $value, in: range, step: step).controlSize(.small).tint(Brand.ember)
        }
    }
}

private struct CountRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(title).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Brand.text).lineLimit(1)
            Spacer(minLength: 6)
            HStack(spacing: 0) {
                step("minus", -1).disabled(value <= range.lowerBound)
                Text("\(value)").font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(Brand.text)
                    .frame(width: 24)
                step("plus", 1).disabled(value >= range.upperBound)
            }
            .padding(2)
            .background(Capsule().fill(Color.black.opacity(0.3)))
            .overlay(Capsule().strokeBorder(Brand.hairline))
        }
    }

    private func step(_ symbol: String, _ delta: Int) -> some View {
        Button { value = min(range.upperBound, max(range.lowerBound, value + delta)) } label: {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold)).foregroundStyle(Brand.text)
                .frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AppRow: View {
    let app: AppEntry
    let label: String
    let note: String?
    let movable: Bool
    let remove: () -> Void
    @State private var hovered = false

    var body: some View {
        let available = app.resolvedURL != nil
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Brand.tertiary).opacity(movable ? (hovered ? 1 : 0.5) : 0)
            Image(nsImage: app.icon).resizable().interpolation(.high).frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Brand.text).lineLimit(1)
                if !available {
                    Text(L("App not found", "App introuvable")).font(.system(size: 10.5)).foregroundStyle(Brand.ember)
                } else if let note {
                    Text(note).font(.system(size: 10.5)).foregroundStyle(Brand.tertiary)
                }
            }
            .opacity(available ? 1 : 0.6)
            Spacer(minLength: 0)
            Button(action: remove) { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                .buttonStyle(IconButtonStyle(size: 20)).opacity(hovered ? 1 : 0).help(L("Remove from group", "Retirer du groupe"))
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(hovered ? Color.white.opacity(0.05) : .clear))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }
}

// MARK: - Controls

private struct SegmentedTabs: View {
    @Binding var selection: InspectorTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(InspectorTab.allCases) { tab in
                Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { selection = tab } } label: {
                    Label(tab.title, systemImage: tab.symbol).labelStyle(TabLabelStyle()).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selection == tab ? Brand.text : Brand.secondary)
                        .frame(maxWidth: .infinity).frame(height: 28)
                        .background {
                            if selection == tab {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.11))
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Brand.highlight))
                                    .matchedGeometryEffect(id: "tab", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.3)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Brand.hairline))
    }
}

private struct TabLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) { configuration.icon.font(.system(size: 10.5, weight: .semibold)); configuration.title }
    }
}

private struct PillPicker<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, title in
                Button { selection = value } label: {
                    Text(title).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(selection == value ? Brand.text : Brand.secondary)
                        .frame(maxWidth: .infinity).frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selection == value ? Brand.ember.opacity(0.18) : .clear))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(selection == value ? Brand.ember.opacity(0.5) : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.3)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Brand.hairline))
    }
}

private struct OptionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol).font(.system(size: 16, weight: .regular))
                    .foregroundStyle(selected ? Brand.ember : Brand.secondary)
                    .frame(width: 22, height: 20, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Brand.text)
                    Text(subtitle).font(.system(size: 10.5)).foregroundStyle(Brand.tertiary).lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .glassCard(selected: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct NoticeBanner: View {
    let notice: Notice?
    var body: some View {
        ZStack {
            if let notice {
                HStack(spacing: 9) {
                    Image(systemName: notice.symbol).foregroundStyle(Brand.ember)
                    Text(notice.text).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Brand.text)
                }
                .padding(.horizontal, 16).frame(height: 38)
                .background(Capsule().fill(.ultraThinMaterial))
                .background(Capsule().fill(Brand.surface.opacity(0.7)))
                .overlay(Capsule().strokeBorder(Brand.highlight))
                .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(notice.id)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: notice)
        .allowsHitTesting(false)
    }
}

// MARK: - Dropped files

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
    group.notify(queue: .main) { completion(results.ordered) }
}
