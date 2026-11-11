//
//  EditorWindow.swift
//  Groupdock
//

import AppKit
import SwiftUI

/// The editor's window. Droppy runs as an accessory app, so the window brings
/// it forward on show; closing it only hides it, and `close()` tears it down.
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
                contentRect: NSRect(x: 0, y: 0, width: 1080, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.title = "GroupDock"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("GroupDockEditor")
            window.contentMinSize = NSSize(width: 980, height: 640)
            window.contentView = NSHostingView(rootView: EditorView(store: store))
            window.delegate = self
            // Droppy is an accessory app: without this the window opens on the
            // Space Droppy last used, not the one the user is looking at.
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            if !window.setFrameUsingName("GroupDockEditor") { window.center() }
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
