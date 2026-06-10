import AppKit
import Carbon
import CoreGraphics
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var statusItem: NSStatusItem!
    private var panel: ClipboardPanel?
    private let viewModel = ClipboardViewModel()
    private let clipboardMonitor = ClipboardMonitor()
    private var previousApp: NSRunningApplication?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var settingsController: SettingsWindowController?

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        setupStatusBar()
        panel = ClipboardPanel(viewModel: viewModel)
        setupHotkey()
        setupClipboardMonitor()
        checkBackend()
    }

    // ── Status Bar ────────────────────────────────────────────────────────────

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
            btn.image?.size = NSSize(width: 16, height: 16)
        }
        let menu = NSMenu()
        let open = NSMenuItem(title: "Abrir Histórico  ⌘⇧V", action: #selector(togglePanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Configurações…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    // ── Hotkey — Carbon RegisterEventHotKey (sem Acessibilidade) ──────────────

    private func setupHotkey() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passRetained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let ptr = userData else { return OSStatus(eventNotHandledErr) }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { delegate.togglePanel() }
                return noErr
            },
            1, &eventSpec, selfPtr, &eventHandlerRef
        )
        updateHotkey(HotkeyConfig.load())
    }

    func updateHotkey(_ config: HotkeyConfig) {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        let id = EventHotKeyID(signature: OSType(0x636c6970), id: 1)
        var idVar = id
        RegisterEventHotKey(config.keyCode, config.modifiers, idVar,
                            GetApplicationEventTarget(), OptionBits(0), &hotKeyRef)
    }

    @objc private func openSettings() {
        if settingsController == nil { settingsController = SettingsWindowController() }
        settingsController?.show()
    }

    // ── Clipboard Monitor ─────────────────────────────────────────────────────

    private func setupClipboardMonitor() {
        clipboardMonitor.onNewContent = { entry in
            Task { await APIClient.shared.addItem(content: entry.content, contentType: entry.contentType) }
        }
        clipboardMonitor.start()
    }

    // ── Panel ─────────────────────────────────────────────────────────────────

    @objc func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            hidePanel()
        } else {
            previousApp = NSWorkspace.shared.frontmostApplication
            panel.showCentered()
        }
    }

    func hidePanel() {
        panel?.orderOut(nil)
    }

    // ── Paste ─────────────────────────────────────────────────────────────────

    func performPaste(item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.contentType {
        case "image":
            if let data = Data(base64Encoded: item.content),
               let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
        case "file":
            let urls = item.content
                .split(separator: "\n")
                .compactMap { URL(fileURLWithPath: String($0)) as NSURL }
            pb.writeObjects(urls)
        default:
            pb.setString(item.content, forType: .string)
        }

        hidePanel()

        let target = previousApp
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            target?.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                simulateCmdV()
            }
        }
    }

    // ── Backend health ────────────────────────────────────────────────────────

    private func checkBackend() {
        Task { @MainActor in
            let online = await APIClient.shared.isReachable()
            viewModel.backendOnline = online
        }
    }
}

// ── Cmd+V via CGEvent ─────────────────────────────────────────────────────────

private func simulateCmdV() {
    let src = CGEventSource(stateID: .hidSystemState)
    let vKey = CGKeyCode(9)
    let dn = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
    let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
    dn?.flags = .maskCommand
    up?.flags = .maskCommand
    dn?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}
