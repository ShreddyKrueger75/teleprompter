import SwiftUI

struct PrompterView: View {
    @Bindable var model: Prompter
    var openSettings: () -> Void
    @State private var hovering = false

    var body: some View {
        let s = model.settings
        GeometryReader { geo in
            let guideY = geo.size.height * 0.35
            ZStack(alignment: .top) {
                s.theme.bg
                Group {
                    if s.guide {
                        s.theme.fg.opacity(0.08)
                            .frame(height: s.fontSize * s.lineSpacing)
                            .offset(y: guideY)
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 6)
                            .offset(y: guideY + s.fontSize * s.lineSpacing / 2 - 6)
                    }
                    Text(model.script.isEmpty ? "Add a script in Script and settings (⌘,)" : model.script)
                        .font(.system(size: s.fontSize, weight: .medium))
                        .lineSpacing(s.fontSize * (s.lineSpacing - 1))
                        .foregroundStyle(s.theme.fg)
                        .multilineTextAlignment(.center)
                        .frame(width: max(40, geo.size.width - s.margin * 2))
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.textHeight = $0 }
                        .offset(y: guideY - model.offset)
                        .frame(maxWidth: .infinity)
                }
                .scaleEffect(x: s.mirrorH ? -1 : 1, y: s.mirrorV ? -1 : 1)

                if model.countdownLeft > 0 {
                    Text("\(model.countdownLeft)")
                        .font(.system(size: geo.size.height * 0.6, weight: .bold))
                        .foregroundStyle(s.theme.fg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(s.theme.bg.opacity(0.85))
                }

                VStack {
                    Spacer()
                    if hovering || !model.playing {
                        ControlBar(model: model, openSettings: openSettings)
                            .transition(.opacity)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: hovering || !model.playing)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 0.5))
        .onHover { hovering = $0 }
    }
}

struct ControlBar: View {
    @Bindable var model: Prompter
    var openSettings: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            button(model.playing || model.countdownLeft > 0 ? "pause.fill" : "play.fill", "Play or pause (⌃⌥Space)") { model.togglePlay() }
            button("backward.end.fill", "Restart (⌃⌥R)") { model.restart() }
            button("gobackward.5", "Jump back 5 s (⌃⌥←)") { model.jumpBack() }
            button("minus", "Slower (⌃⌥↓)") { model.adjustSpeed(-0.1) }
            Text(model.settings.speed, format: .number.precision(.fractionLength(1)))
                .monospacedDigit()
                .frame(width: 30)
            button("plus", "Faster (⌃⌥↑)") { model.adjustSpeed(0.1) }
            Spacer()
            Text("\(clock(model.elapsed)) / \(clock(model.duration))")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
            toggle("flip.horizontal", "Mirror horizontally", $model.settings.mirrorH)
            toggle("eye.slash", "Hide from screen sharing", $model.settings.hideFromShare)
            toggle("mic", "Scroll by voice", $model.settings.voice)
            button("gearshape", "Script and settings (⌘,)") { openSettings() }
        }
        .font(.system(size: 12))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.85))
    }

    private func button(_ icon: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 22, height: 20).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func toggle(_ icon: String, _ help: String, _ on: Binding<Bool>) -> some View {
        button(icon, help) { on.wrappedValue.toggle() }
            .foregroundStyle(on.wrappedValue ? .green : .white)
    }

    private func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }
}
