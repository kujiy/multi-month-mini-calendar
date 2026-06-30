import SwiftUI
import AppKit

/// Owns the status-bar item, the popover, and the Settings window. Using
/// AppKit's `NSStatusItem` + `NSPopover` (rather than SwiftUI's `MenuBarExtra`)
/// so the popover resizes live when the layout changes: `NSHostingController`'s
/// `preferredContentSize` tracks the SwiftUI content and `NSPopover` follows it.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only: no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        let hosting = NSHostingController(
            rootView: PopoverView(prefs: .shared, holidays: .shared) { [weak self] in
                self?.showSettings()
            }
        )
        // Make the popover track the SwiftUI content's intrinsic size so it
        // grows/shrinks as the layout/month-count changes.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        // No open/close animation.
        popover.animates = false
        // `.applicationDefined` keeps the popover open even when another window
        // (e.g. Settings) becomes key, so layout changes are visible live. We
        // emulate "click outside closes" ourselves via a global click monitor.
        popover.behavior = .applicationDefined

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "calendar",
                accessibilityDescription: "Calendar"
            )
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()

        // Close when the user clicks outside this app (another app, the
        // desktop, etc.). Global monitors fire only for events delivered to
        // *other* apps, so clicking our own Settings window keeps it open.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    /// Presents the Settings window, creating it lazily. Managed directly in
    /// AppKit so it works reliably from the popover (which lives outside the
    /// SwiftUI scene graph) and is brought to the front for this accessory app.
    private func showSettings() {
        // Intentionally leave the popover open so layout changes are visible
        // live while the Settings window is in front.
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: PreferencesView(prefs: .shared))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Preferences"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

@main
struct MultiMonthMiniCalendarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu-bar item, popover, and Settings window are all managed by
        // the AppDelegate. This empty Settings scene only satisfies the App's
        // requirement for a scene; it is never presented.
        Settings { EmptyView() }
    }
}
