import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Borderless windows refuse key status by default; the control bar needs it.
final class PrompterWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = Prompter()
    private var prompter: NSWindow!
    private var settings: NSWindow!
    private var hotKeys: [EventHotKeyRef?] = []

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

    // MARK: windows

    private func makeWindows() {
        let p = PrompterWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 180),
                               styleMask: [.borderless, .resizable, .fullSizeContentView],
                               backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.isReleasedWhenClosed = false
        p.minSize = NSSize(width: 240, height: 90)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.contentView = NSHostingView(rootView: PrompterView(model: model) { [weak self] in self?.showSettings() })
        if !p.setFrameUsingName("Prompter"), let screen = NSScreen.main {
            // first launch: park it top-centre, right under the camera
            let f = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: f.midX - 240, y: f.maxY - 180))
        }
        p.setFrameAutosaveName("Prompter")
        prompter = p

        let s = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        s.title = "Teleprompter"
        s.isReleasedWhenClosed = false
        s.contentView = NSHostingView(rootView: SettingsView(model: model))
        s.center()
        s.setFrameAutosaveName("Settings")
        settings = s
    }

    private func applyWindowSettings() {
        let s = model.settings
        prompter.level = s.alwaysOnTop ? .floating : .normal
        prompter.sharingType = s.hideFromShare ? .none : .readOnly
        prompter.alphaValue = s.opacity
    }

    @objc private func showSettings() {
        settings.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePrompter() {
        prompter.isVisible ? prompter.orderOut(nil) : prompter.orderFront(nil)
    }

    @objc private func togglePlay() { model.togglePlay() }
    @objc private func restart() { model.restart() }
    @objc private func jumpBack() { model.jumpBack() }
    @objc private func faster() { model.adjustSpeed(0.1) }
    @objc private func slower() { model.adjustSpeed(-0.1) }

    // MARK: menu

    private func buildMenu() {
        let main = NSMenu()

        let app = NSMenu()
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

        let ctl = NSMenu(title: "Prompter")
        ctl.addItem(withTitle: "Play / Pause", action: #selector(togglePlay), keyEquivalent: "\r")
        ctl.addItem(withTitle: "Restart", action: #selector(restart), keyEquivalent: "r")
        ctl.addItem(withTitle: "Jump back 5 s", action: #selector(jumpBack), keyEquivalent: String(UnicodeScalar(NSLeftArrowFunctionKey)!))
        ctl.addItem(withTitle: "Faster", action: #selector(faster), keyEquivalent: String(UnicodeScalar(NSUpArrowFunctionKey)!))
        ctl.addItem(withTitle: "Slower", action: #selector(slower), keyEquivalent: String(UnicodeScalar(NSDownArrowFunctionKey)!))
        ctl.addItem(.separator())
        ctl.addItem(withTitle: "Show / Hide Prompter", action: #selector(togglePrompter), keyEquivalent: "p")
        main.addItem(withTitle: "Prompter", action: nil, keyEquivalent: "").submenu = ctl

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
        for (i, code) in [kVK_Space, kVK_UpArrow, kVK_DownArrow, kVK_LeftArrow, kVK_ANSI_R, kVK_ANSI_H].enumerated() {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(UInt32(code), mods, EventHotKeyID(signature: 0x54504D54, id: UInt32(i)),
                                GetApplicationEventTarget(), 0, &ref)
            hotKeys.append(ref)
        }
    }

    private func hotKey(_ id: UInt32) {
        switch id {
        case 0: model.togglePlay()
        case 1: model.adjustSpeed(0.1)
        case 2: model.adjustSpeed(-0.1)
        case 3: model.jumpBack()
        case 4: model.restart()
        case 5: togglePrompter()
        default: break
        }
    }
}
