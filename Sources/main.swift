import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // sem ícone no Dock
let delegate = AppDelegate()
app.delegate = delegate
app.run()
