import AppKit

// Pure menu-bar app: no Dock icon, no app switcher entry
NSApplication.shared.setActivationPolicy(.accessory)

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
