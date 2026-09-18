import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var model: Prompter
    @State private var previousScript: String?
    @State private var pendingReplace: (name: String, text: String)?
    @State private var fileError: String?

    var body: some View {
        HStack(spacing: 0) {
            editor
            Divider()
            form
        }
        .confirmationDialog("Replace the script?", isPresented: .constant(pendingReplace != nil)) {
            Button("Replace", role: .destructive) { if let p = pendingReplace { commit(p.text) }; pendingReplace = nil }
            Button("Cancel", role: .cancel) { pendingReplace = nil }
        } message: {
            Text("\(pendingReplace?.name ?? "") replaces the \(model.wordCount) words already here. You can undo this straight afterwards.")
        }
    }

    // MARK: script

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Open file…") { openFile() }
                Button("From clipboard") {
                    guard let s = NSPasteboard.general.string(forType: .string), !s.isEmpty else {
                        fileError = "There is no text on the clipboard."
                        return
                    }
                    replace(s, named: "The clipboard")
                }
                Button("Clear") { replace("", named: "Clearing the script") }
                    .disabled(model.script.isEmpty)
                if previousScript != nil {
                    Button("Undo") {
                        if let p = previousScript { model.script = p }
                        previousScript = nil
                    }
                }
                Spacer()
                Text(readout)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            if let fileError {
                Label(fileError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            TextEditor(text: $model.script)
                .font(.system(size: 13))
                .accessibilityLabel("Script")
        }
        .padding()
        .frame(minWidth: 320)
    }

    private var readout: String {
        let words = model.wordCount
        let label = words == 1 ? "1 word" : "\(words) words"
        guard words > 0 else { return "No script yet" }
        let secs = Int(model.duration.rounded())
        return "\(label) · about \(secs / 60):" + String(format: "%02d", secs % 60)
    }

    // MARK: settings

    private var form: some View {
        Form {
            Section("Where is your camera?") {
                Picker("Setup", selection: Binding(get: { model.settings.rig },
                                                   set: { model.apply(rig: $0) })) {
                    ForEach(Rig.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.radioGroup)
                Text(model.settings.rig.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Reading") {
                slider("Pace", $model.settings.wpm, 60...240, 5, "wpm")
                slider("Font size", $model.settings.fontSize, model.settings.rig.fontRange, 1, "pt")
                slider("Line spacing", $model.settings.lineSpacing, 1...2.5, 0.1, "×")
                slider("Side margins", $model.settings.margin, 0...120, 1, "pt")
                Stepper(value: $model.settings.countdown, in: 0...10) {
                    HStack {
                        Text("Countdown")
                        Spacer()
                        Text(model.settings.countdown == 0 ? "Off" : "\(model.settings.countdown) s")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Reading guide", isOn: $model.settings.guide)
            }

            Section("Window") {
                Picker("Colours", selection: $model.settings.theme) {
                    ForEach(Theme.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                slider("Background", $model.settings.opacity, 0.3...1, 0.05, "%")
                Toggle("Always on top", isOn: $model.settings.alwaysOnTop)
                Toggle("Hide from screen sharing", isOn: $model.settings.hideFromShare)
                Text("Your script stays out of screen shares and recordings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Mirroring") {
                Toggle("Mirror horizontally", isOn: $model.settings.mirrorH)
                Toggle("Mirror vertically", isOn: $model.settings.mirrorV)
            }

            Section("Voice") {
                Toggle("Scroll as I speak", isOn: $model.settings.voice)
                    .onChange(of: model.settings.voice) { _, on in if on { model.prepareVoice() } }
                if let notice = model.notice {
                    Label(notice, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                } else {
                    Text("Recognition runs on this Mac. Audio is never sent anywhere.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Hotkeys, which work while another app is in front") {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                    row("Control Option Space", "Play or pause")
                    row("Control Option Up", "Faster")
                    row("Control Option Down", "Slower")
                    row("Control Option Left", "Back 5 seconds")
                    row("Control Option Right", "Forward 5 seconds")
                    row("Control Option R", "Restart")
                    row("Control Option H", "Show or hide the prompter")
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
    }

    private func row(_ keys: String, _ what: String) -> some View {
        GridRow {
            Text(keys).foregroundStyle(.secondary)
            Text(what)
        }
    }

    // MARK: script replacement, always undoable

    private func replace(_ text: String, named name: String) {
        fileError = nil
        guard !model.script.isEmpty else { commit(text); return }
        pendingReplace = (name, text)
    }

    private func commit(_ text: String) {
        previousScript = model.script
        model.script = text
    }

    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>,
                        _ step: Double, _ unit: String) -> some View {
        // ponytail: rounding in the binding, not `step:`, so the track has no tick smear
        let rounded = Binding(get: { value.wrappedValue },
                              set: { value.wrappedValue = ((($0 / step).rounded()) * step) })
        return HStack {
            Text(label).frame(width: 96, alignment: .leading)
            Slider(value: rounded, in: range)
                .accessibilityLabel(label)
                .accessibilityValue(display(value.wrappedValue, unit))
            Text(display(value.wrappedValue, unit))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .trailing)
        }
    }

    private func display(_ v: Double, _ unit: String) -> String {
        switch unit {
        case "%": "\(Int((v * 100).rounded()))%"
        case "×": String(format: "%.1f×", v)
        case "wpm": "\(Int(v.rounded())) wpm"
        default: "\(Int(v.rounded())) \(unit)"
        }
    }

    private func openFile() {
        fileError = nil
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .utf8PlainText, UTType("net.daringfireball.markdown") ?? .plainText]
        panel.allowsOtherFileTypes = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            replace(text, named: url.lastPathComponent)
        } catch {
            // ponytail: one retry as Latin-1 covers most non-UTF8 scripts people actually have
            if let fallback = try? String(contentsOf: url, encoding: .isoLatin1) {
                replace(fallback, named: url.lastPathComponent)
            } else {
                fileError = "\(url.lastPathComponent) could not be read as text. Save it as plain text and try again."
            }
        }
    }
}
