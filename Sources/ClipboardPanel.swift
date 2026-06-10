import AppKit
import SwiftUI

final class ClipboardPanel: NSPanel {
    private let viewModel: ClipboardViewModel

    init(viewModel: ClipboardViewModel) {
        self.viewModel = viewModel
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        configure()
    }

    private func configure() {
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        level = .floating
        collectionBehavior = [.canJoinAllSpaces]
        isOpaque = true
        backgroundColor = NSColor.windowBackgroundColor
        hasShadow = true

        let root = ClipboardHistoryView().environmentObject(viewModel)
        contentView = NSHostingView(rootView: root)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func showCentered() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let sf = screen.visibleFrame
        let w: CGFloat = 440, h: CGFloat = 560
        let x = sf.origin.x + (sf.width  - w) / 2
        let y = sf.origin.y + (sf.height - h) / 2 + 30
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        makeKeyAndOrderFront(nil)
        NSApp.activate()
        viewModel.load()
        viewModel.searchText = ""
    }
}
