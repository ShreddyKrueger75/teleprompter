import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var model: Prompter

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("Open file…") { openFile() }
                    Button("Paste") { if let s = NSPasteboard.general.string(forType: .string) { model.script = s } }
                    Button("Clear") { model.script = "" }
                    Spacer()
                    Text("\(wordCount) words")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                TextEditor(text: $model.script)
                    .font(.system(size: 13))
            }
            .padding()
            .frame(minWidth: 320)

            Divider()

            Form {
                slider("Speed", $model.settings.speed, 0.2...3, 0.1, "×")
                slider("Font size", $model.settings.fontSize, 14...96, 1, " pt")
                slider("Line spacing", $model.settings.lineSpacing, 1...2.5, 0.1, "×")
                slider("Margins", $model.settings.margin, 0...120, 1, " px")
                slider("Opacity", $model.settings.opacity, 0.3...1, 0.05, "")
                Stepper("Countdown: \(model.settings.countdown) s", value: $model.settings.countdown, in: 0...10)
                Picker("Colours", selection: $model.settings.theme) {
                    ForEach(Theme.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Toggle("Reading guide", isOn: $model.settings.guide)
                Toggle("Mirror horizontally", isOn: $model.settings.mirrorH)
                Toggle("Mirror vertically", isOn: $model.settings.mirrorV)
                Toggle("Always on top", isOn: $model.settings.alwaysOnTop)
                Toggle("Hide from screen sharing", isOn: $model.settings.hideFromShare)
                Toggle("Scroll by voice (on-device speech)", isOn: $model.settings.voice)
                Section("Hotkeys work in any app") {
                    Text("""
                    ⌃⌥ Space  play / pause
                    ⌃⌥ ↑ ↓  faster / slower
                    ⌃⌥ ←  jump back 5 s
                    ⌃⌥ R  restart
                    ⌃⌥ H  show / hide prompter
                    """)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(width: 340)
        }
    }

    private var wordCount: Int { model.script.split { $0.isWhitespace }.count }

    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ step: Double, _ unit: String) -> some View {
        HStack {
            Text(label).frame(width: 90, alignment: .leading)
            Slider(value: value, in: range, step: step)
            (Text(value.wrappedValue, format: .number.precision(.fractionLength(step < 1 ? 1 : 0))) + Text(unit))
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text]
        guard panel.runModal() == .OK, let url = panel.url,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        model.script = text
    }
}
