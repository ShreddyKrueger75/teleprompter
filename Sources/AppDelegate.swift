import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Borderless windows refuse key status by default; the control bar needs it.
final class PrompterWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    /// Scrubbing the script with the trackpad. Handled at the window, because no SwiftUI
    /// view claims scroll events, and so the buttons above keep their own clicks.
    var onScroll: ((CGFloat) -> Void)?
    override func scrollWheel(with event: NSEvent) {
        // Trackpads report points; a wheel mouse reports lines, so scale those up
        // or a whole detent moves the script barely a pixel.
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 16
        onScroll?(-delta)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = Prompter()
    private var prompter: NSWindow!
    private var settings: NSWindow!
    private var hotKeys: [EventHotKeyRef?] = []
    private var hotKeyActions: [UInt32] = []
    private var showHideItem: NSMenuItem?

    func applicationDidFinishLaunching(_ note: Notification) {
        buildMenu()
        makeWindows()
        registerHotKeys()
        model.onSettingsChange = { [weak self] in self?.applyWindowSettings() }
        applyWindowSettings()
        prompter.orderFront(nil)
        if model.script.isEmpty { showSettings() }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Clicking the Dock icon brings the prompter back after ⌃⌥H hid it.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        prompter.orderFront(nil)
        syncShowHideTitle()
        return true
    }

    // MARK: windows

    private func makeWindows() {
        let p = PrompterWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 200),
                               styleMask: [.borderless, .resizable, .fullSizeContentView],
                               backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.isReleasedWhenClosed = false
        // Small enough to tuck under a notch, never so small the controls clip.
        p.minSize = NSSize(width: 320, height: 140)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.contentView = NSHostingView(rootView: PrompterView(model: model) { [weak self] in self?.showSettings() })
        p.onScroll = { [weak self] delta in
            // Scrubbing is a paused-only gesture, and a countdown counts as running.
            guard let self, !model.playing, model.countdownLeft == 0 else { return }
            model.seek(to: model.offset + delta)
        }
        if !p.setFrameUsingName("Prompter"), let screen = NSScreen.main {
            // first launch: park it top-centre, right under the camera
            let f = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: f.midX - 260, y: f.maxY - 200))
        }
        p.setFrameAutosaveName("Prompter")
        prompter = p

        let s = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        s.title = "Script and settings"
        s.isReleasedWhenClosed = false
        s.minSize = NSSize(width: 720, height: 460)
        s.contentView = NSHostingView(rootView: SettingsView(model: model))
        s.center()
        s.setFrameAutosaveName("Settings")
        settings = s
    }

    private func applyWindowSettings() {
        let s = model.settings
        prompter.level = s.alwaysOnTop ? .floating : .normal
        prompter.sharingType = s.hideFromShare ? .none : .readOnly
    }

    @objc private func showSettings() {
        settings.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePrompter() {
        prompter.isVisible ? prompter.orderOut(nil) : prompter.orderFront(nil)
        syncShowHideTitle()
    }

    private func syncShowHideTitle() {
        showHideItem?.title = prompter.isVisible ? "Hide prompter" : "Show prompter"
    }

    @objc private func openHelp() {
        guard let url = URL(string: "https://github.com/ShreddyKrueger75/teleprompter#readme") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func togglePlay() { model.togglePlay() }
    @objc private func restart() { model.restart() }
    @objc private func jumpBack() { model.jumpBack() }
    @objc private func jumpForward() { model.jumpForward() }
    @objc private func faster() { model.adjustWPM(5) }
    @objc private func slower() { model.adjustWPM(-5) }

    // MARK: menu

    private func buildMenu() {
        let main = NSMenu()

        let app = NSMenu()
        app.addItem(withTitle: "About Teleprompter", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Script and settings…", action: #selector(showSettings), keyEquivalent: ",")
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Teleprompter", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit Teleprompter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "Teleprompter", action: nil, keyEquivalent: "").submenu = app

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = edit

        // No key equivalents here: these actions belong to the global ⌃⌥ hotkeys, and
        // ⌘-arrows are caret movement while the script is being edited.
        let ctl = NSMenu(title: "Prompter")
        for (title, sel) in [("Play or pause", #selector(togglePlay)),
                             ("Restart", #selector(restart)),
                             ("Back 5 seconds", #selector(jumpBack)),
                             ("Forward 5 seconds", #selector(jumpForward)),
                             ("Faster", #selector(faster)),
                             ("Slower", #selector(slower))] {
            ctl.addItem(withTitle: title, action: sel, keyEquivalent: "")
        }
        ctl.addItem(.separator())
        let hide = NSMenuItem(title: "Hide prompter", action: #selector(togglePrompter), keyEquivalent: "")
        ctl.addItem(hide)
        showHideItem = hide
        main.addItem(withTitle: "Prompter", action: nil, keyEquivalent: "").submenu = ctl

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Minimise", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = window
        NSApp.windowsMenu = window

        let help = NSMenu(title: "Help")
        help.addItem(withTitle: "Teleprompter help", action: #selector(openHelp), keyEquivalent: "?")
        help.addItem(withTitle: "Hotkeys and settings…", action: #selector(showSettings), keyEquivalent: "")
        main.addItem(withTitle: "Help", action: nil, keyEquivalent: "").submenu = help
        NSApp.helpMenu = help

        NSApp.mainMenu = main
    }

    // MARK: global hotkeys (Carbon; no Accessibility permission needed)

    private func registerHotKeys() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let me = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
            Task { @MainActor in me.hotKey(id.id) }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)

        let mods = UInt32(controlKey | optionKey)
        // ⌃⌥Space is macOS's own "select previous input source" for anyone with more than
        // one keyboard layout, so ⌃⌥P plays too and the app works either way.
        let keys: [(key: Int, name: String, action: UInt32)] = [
            (kVK_Space, "Space", 0), (kVK_ANSI_P, "P", 0),
            (kVK_UpArrow, "Up", 1), (kVK_DownArrow, "Down", 2),
            (kVK_LeftArrow, "Left", 3), (kVK_ANSI_R, "R", 4),
            (kVK_ANSI_H, "H", 5), (kVK_RightArrow, "Right", 6),
        ]
        var failed: [String] = []
        for (i, key) in keys.enumerated() {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(key.key), mods,
                                             EventHotKeyID(signature: 0x54504D54, id: UInt32(i)),
                                             GetApplicationEventTarget(), 0, &ref)
            // A hotkey another app already owns must not fail silently.
            status == noErr ? hotKeys.append(ref) : failed.append("Control Option \(key.name)")
        }
        hotKeyActions = keys.map(\.action)
        if !failed.isEmpty {
            model.hotkeyNotice = "Another app already uses \(failed.joined(separator: ", ")), so that hotkey will not reach Teleprompter. The others still work."
        }
    }

    private func hotKey(_ id: UInt32) {
        // Registration order and action are decoupled, so two keys can share one action.
        guard Int(id) < hotKeyActions.count else { return }
        switch hotKeyActions[Int(id)] {
        case 0: model.togglePlay()
        case 1: model.adjustWPM(5)
        case 2: model.adjustWPM(-5)
        case 3: model.jumpBack()
        case 4: model.restart()
        case 5: togglePrompter()
        case 6: model.jumpForward()
        default: break
        }
    }
}
