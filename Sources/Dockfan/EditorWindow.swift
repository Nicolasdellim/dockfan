//
//  EditorWindow.swift
//  Dockfan
//

import AppKit
import SwiftUI

/// The editor's window. Droppy runs as an accessory app, so showing the
/// window brings Droppy forward on the Space the user is looking at.
@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: GroupStore

    init(store: GroupStore) {
        self.store = store
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1140, height: 740),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.title = "Dockfan"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(Brand.ink)
            window.contentMinSize = NSSize(width: 1040, height: 680)
            window.contentView = NSHostingView(rootView: EditorView(store: store))
            window.delegate = self
            // Without this the window opens on the Space Droppy last used.
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.setFrameAutosaveName("DockfanEditor")
            if !window.setFrameUsingName("DockfanEditor") { window.center() }
            self.window = window
        }
        store.refreshDockState()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        store.refreshDockState()
    }

    func close() {
        window?.delegate = nil
        window?.close()
        window = nil
    }
}
