import SwiftUI
import AppKit
import Carbon
import ServiceManagement

// ── Window controller ─────────────────────────────────────────────────────────

final class SettingsWindowController: NSWindowController {
    init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 175),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "ClipRecall — Configurações"
        win.isReleasedWhenClosed = false
        win.center()
        super.init(window: win)
        win.contentView = NSHostingView(rootView: SettingsView())
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

// ── SwiftUI view ──────────────────────────────────────────────────────────────

struct SettingsView: View {
    @State private var config = HotkeyConfig.load()
    @State private var isRecording = false
    @State private var saved = false
    @State private var localMonitor: Any?
    @State private var launchAtLogin: Bool = {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Atalho global")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: toggleRecording) {
                    Text(isRecording ? "Pressione o atalho…" : config.displayString)
                        .frame(width: 140)
                        .animation(nil, value: isRecording)
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? .orange : .accentColor)
            }

            Divider()

            Toggle("Inicializar com o Mac", isOn: $launchAtLogin)
                .font(.system(size: 13))
                .onChange(of: launchAtLogin) { _, enabled in
                    if #available(macOS 13.0, *) {
                        if enabled {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
                }

            Divider()

            HStack {
                Button("Restaurar padrão") {
                    config = .default
                    stopRecording()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

                Spacer()

                if saved {
                    Label("Salvo", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }

                Button("Salvar") { save() }
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 13))
            }
        }
        .padding(20)
        .onDisappear { stopRecording() }
    }

    // ── Recording ─────────────────────────────────────────────────────────────

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc cancela
            if event.keyCode == 53 { stopRecording(); return nil }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var mods: UInt32 = 0
            if flags.contains(.command) { mods |= UInt32(cmdKey) }
            if flags.contains(.shift)   { mods |= UInt32(shiftKey) }
            if flags.contains(.option)  { mods |= UInt32(optionKey) }
            if flags.contains(.control) { mods |= UInt32(controlKey) }

            guard mods != 0 else { return event }

            config = HotkeyConfig(keyCode: UInt32(event.keyCode), modifiers: mods)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    private func save() {
        stopRecording()
        config.save()
        AppDelegate.shared?.updateHotkey(config)
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { saved = false }
        }
    }
}
