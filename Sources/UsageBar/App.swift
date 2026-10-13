import AppKit
import SwiftUI
import UsageCore

@main
@MainActor
struct UsageBarApp {
    static func main() {
        if CommandLine.arguments.contains("--check") {
            Task {
                let client = UsageClient()
                var failed = false
                for provider in Provider.allCases {
                    do {
                        let snapshot = try await client.fetch(provider)
                        print("\(provider.rawValue): \(snapshot.remainingPercent.map { "\($0)% remaining" } ?? "unavailable")")
                        for window in snapshot.windows {
                            let reset = window.resetsAt?.formatted(date: .abbreviated, time: .shortened) ?? "unknown"
                            print("  \(window.title): \(Int(window.usedPercent.rounded()))% used; resets \(reset)")
                        }
                    } catch {
                        failed = true
                        print("\(provider.rawValue): \(error.localizedDescription)")
                    }
                }
                exit(failed ? 1 : 0)
            }
            dispatchMain()
        }
        let application = NSApplication.shared
        if let index = CommandLine.arguments.firstIndex(of: "--appearance"),
           CommandLine.arguments.indices.contains(index + 1) {
            switch CommandLine.arguments[index + 1] {
            case "light": application.appearance = NSAppearance(named: .aqua)
            case "dark": application.appearance = NSAppearance(named: .darkAqua)
            default: break
            }
        }
        let delegate = AppDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private let popover = NSPopover()
    private var item: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.item = item
        item.button?.title = store.statusTitle
        item.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.setAccessibilityLabel("Claude and Codex subscription usage")
        let appearance = NSApplication.shared.appearance
        let colorScheme: ColorScheme? = appearance.map { $0.name == .aqua ? .light : .dark }
        let controller = NSHostingController(rootView: UsagePopover(store: store).preferredColorScheme(colorScheme))
        controller.sizingOptions = [.preferredContentSize]
        popover.appearance = appearance
        popover.contentViewController = controller
        popover.behavior = .transient
        store.onChange = { [weak self] in self?.updateStatus() }
        store.start()
        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.showPopover() }
        }
    }

    private func updateStatus() {
        item?.button?.title = store.statusTitle
        item?.button?.toolTip = "Claude / Codex: lowest remaining limit. Click for usage and reset times."
        item?.button?.setAccessibilityValue(store.statusTitle + " remaining")
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil) }
        else { showPopover() }
    }

    private func showPopover() {
        guard let button = item?.button else { return }
        store.refreshIfNeeded()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }
}
