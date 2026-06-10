import Carbon

struct HotkeyConfig: Codable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = HotkeyConfig(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    static func load() -> HotkeyConfig {
        guard let data = UserDefaults.standard.data(forKey: "hotkeyConfig"),
              let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data)
        else { return .default }
        return config
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "hotkeyConfig")
        }
    }

    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += keyCodeLabel(keyCode)
        return s
    }
}

private func keyCodeLabel(_ code: UInt32) -> String {
    let map: [UInt32: String] = [
        0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X",
        8:"C", 9:"V", 11:"B", 12:"Q", 13:"W", 14:"E", 15:"R",
        16:"Y", 17:"T", 31:"O", 32:"U", 34:"I", 35:"P", 37:"L",
        38:"J", 40:"K", 45:"N", 46:"M",
        18:"1", 19:"2", 20:"3", 21:"4", 22:"6", 23:"5",
        25:"9", 26:"7", 28:"8", 29:"0",
        36:"↩", 48:"⇥", 49:"Space", 51:"⌫",
        123:"←", 124:"→", 125:"↓", 126:"↑",
    ]
    return map[code] ?? "?\(code)"
}
