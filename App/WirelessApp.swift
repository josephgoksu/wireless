import SwiftUI

@main
struct WirelessApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Window("Wireless", id: "wireless") {
            RadioView()
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keyboard and scroll wheel work anywhere on the set: ←/→ tune, ↑/↓ volume, space power, 1–8 presets.
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { event in
            let radio = Radio.shared
            if event.type == .scrollWheel {
                radio.tune(by: -Double(event.scrollingDeltaY) * (event.hasPreciseScrollingDeltas ? 0.004 : 0.1))
                return nil
            }
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
            switch event.keyCode {
            case 123: radio.tune(by: -0.1)
            case 124: radio.tune(by: 0.1)
            case 126: radio.volume = min(1, radio.volume + 0.05)
            case 125: radio.volume = max(0, radio.volume - 0.05)
            case 49: radio.power(!radio.isOn)
            default:
                guard let n = Int(event.charactersIgnoringModifiers ?? ""), Station.all.indices.contains(n - 1) else { return event }
                radio.press(Station.all[n - 1])
            }
            return nil
        }
    }

    /// Clicks on the desktop widget arrive here as wireless:// links.
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(Radio.shared.open)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
