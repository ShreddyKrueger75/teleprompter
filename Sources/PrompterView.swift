import SwiftUI

struct PrompterView: View {
    @Bindable var model: Prompter
    var openSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var barShown = true
    @State private var hideBar: DispatchWorkItem?

    /// Chrome is present while paused, and gets out of the way once the read starts.
    private var barVisible: Bool { !model.playing || barShown }

    var body: some View {
        let s = model.settings
        GeometryReader { geo in
            let guideY = geo.size.height * s.rig.guidePosition
            let lineHeight = s.fontSize * s.lineSpacing
            ZStack(alignment: .top) {
                // Opacity dims the backing, never the words: the script stays readable
                // at every setting.
                s.theme.bg.opacity(s.opacity)

                Group {
                    if s.guide {
                        // Capped, or a 240 pt font turns the band into most of the window.
                        s.theme.fg.opacity(0.14)
                            .frame(height: min(lineHeight, geo.size.height * 0.4))
                            .offset(y: guideY)
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: max(10, s.fontSize * 0.38)))
                            .foregroundStyle(s.theme.marker)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 6)
                            .offset(y: guideY + lineHeight / 2 - max(10, s.fontSize * 0.38) * 0.6)
                    }

                    scriptText(width: geo.size.width, guideY: guideY)

                    if model.countdownLeft > 0 {
                        // Sits above the reading line so the first words stay readable,
                        // and inside the mirrored group so it is not backwards on glass.
                        Text("\(model.countdownLeft)")
                            .font(.system(size: min(guideY * 0.8, geo.size.height * 0.3), weight: .bold))
                            .foregroundStyle(s.theme.fg)
                            .frame(maxWidth: .infinity)
                            .offset(y: max(0, guideY * 0.1))
                            .accessibilityLabel("Starting in \(model.countdownLeft) seconds")
                    }
                }
                .scaleEffect(x: s.mirrorH ? -1 : 1, y: s.mirrorV ? -1 : 1)
            }
            // The script is taller than the window on purpose, so the window is pinned to
            // its own size and clips; chrome then sits on the window, not on the script.
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .clipped()
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    if barVisible {
                        ControlBar(model: model, width: geo.size.width, openSettings: openSettings)
                            .transition(.opacity)
                    }
                    ProgressHairline(progress: model.progress, theme: s.theme)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: barVisible)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onContinuousHover { phase in
            switch phase {
            case .active: poke()
            case .ended: if model.playing { barShown = false }
            }
        }
        .onChange(of: model.playing) { poke() }
    }

    @ViewBuilder
    private func scriptText(width: CGFloat, guideY: CGFloat) -> some View {
        let s = model.settings
        if model.script.isEmpty {
            Text("Add a script in Script and settings (⌘,)")
                .font(.system(size: min(s.fontSize, 28), weight: .medium))
                .foregroundStyle(s.theme.fg.opacity(0.65))
                .frame(maxWidth: .infinity)
                .offset(y: guideY)
        } else {
            Text(model.script)
                .font(.system(size: s.fontSize, weight: .medium))
                .lineSpacing(s.fontSize * (s.lineSpacing - 1))
                .multilineTextAlignment(.center)
                .foregroundStyle(s.theme.fg)
                .frame(width: max(40, width - s.margin * 2))
                // The script lays out at its full natural height; the window is a viewport
                // onto it, so long scripts scroll instead of truncating.
                .fixedSize(horizontal: false, vertical: true)
                // Measured on the words alone. The end mark below must not count, or the
                // reader finishes early and the clock disagrees with them.
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.textHeight = $0 }
                // Keeps the script readable when the background is turned down and a bright
                // desktop or video call shows through behind it.
                .shadow(color: s.theme.bg.opacity(s.opacity < 1 ? 0.9 : 0), radius: max(2, s.fontSize * 0.09))
                .overlay(alignment: .bottom) {
                    Text("End of script")
                        .font(.system(size: max(12, s.fontSize * 0.45), weight: .semibold))
                        .foregroundStyle(s.theme.fg.opacity(0.85))
                        .alignmentGuide(.bottom) { $0[.top] - s.fontSize }
                }
                .offset(y: guideY - model.offset)
                .frame(maxWidth: .infinity)
        }
    }

    private func poke() {
        barShown = true
        hideBar?.cancel()
        guard model.playing else { return }
        let work = DispatchWorkItem { barShown = false }
        hideBar = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }
}

/// How far through the script the reader is, without asking them to look away from the lens.
struct ProgressHairline: View {
    let progress: Double
    let theme: Theme

    var body: some View {
        GeometryReader { geo in
            theme.fg.opacity(0.45)
                .frame(width: geo.size.width * progress)
        }
        .frame(height: 2)
        .background(Color(white: 0.04))
        .accessibilityHidden(true)
    }
}

struct ControlBar: View {
    @Bindable var model: Prompter
    let width: CGFloat
    var openSettings: () -> Void

    // The bar sheds its least urgent controls before it ever clips.
    private var showsClock: Bool { width >= 430 }
    private var showsModes: Bool { width >= 340 }

    var body: some View {
        HStack(spacing: 2) {
            button(model.playing || model.countdownLeft > 0 ? "pause.fill" : "play.fill",
                   model.playing || model.countdownLeft > 0 ? "Pause" : "Play",
                   "⌃⌥Space") { model.togglePlay() }
            button("backward.end.fill", "Restart", "⌃⌥R") { model.restart() }
            button("gobackward.5", "Back 5 seconds", "⌃⌥←") { model.jumpBack() }
            button("goforward.5", "Forward 5 seconds", "⌃⌥→") { model.jumpForward() }
            button("minus", "Slower", "⌃⌥↓") { model.adjustWPM(-5) }
            Text("\(Int(model.settings.wpm))")
                .monospacedDigit()
                .frame(width: 26)
                .accessibilityLabel("Reading pace")
                .accessibilityValue("\(Int(model.settings.wpm)) words per minute")
            button("plus", "Faster", "⌃⌥↑") { model.adjustWPM(5) }
            Spacer(minLength: 6)
            if showsClock {
                Text("\(clock(model.elapsed)) / \(clock(model.duration))")
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.trailing, 4)
                    .accessibilityLabel("Position")
                    .accessibilityValue("\(clock(model.elapsed)) of \(clock(model.duration))")
            }
            if showsModes {
                toggle(on: "flip.horizontal.fill", off: "flip.horizontal",
                       "Mirror horizontally", $model.settings.mirrorH)
                toggle(on: "eye.slash.fill", off: "eye",
                       "Hide from screen sharing", $model.settings.hideFromShare)
            }
            // The microphone indicator stays even in the narrowest bar: a live mic must
            // never be listening with nothing on screen to say so.
            if showsModes || model.settings.voice {
                toggle(on: model.voiceState == .listening ? "waveform" : "mic.fill", off: "mic.slash",
                       "Scroll by voice", $model.settings.voice)
            }
            button("gearshape", "Script and settings", "⌘,") { openSettings() }
        }
        .font(.system(size: 12))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(white: 0.04))   // solid, so the script never ghosts through the chrome
    }

    private func button(_ icon: String, _ label: String, _ key: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(key.map { "\(label) (\($0))" } ?? label)
        .accessibilityLabel(label)
    }

    /// Icon changes with state, so the control never reads as "on" by colour alone.
    private func toggle(on: String, off: String, _ label: String, _ binding: Binding<Bool>) -> some View {
        let isOn = binding.wrappedValue
        return button(isOn ? on : off, label, nil) { binding.wrappedValue.toggle() }
            .foregroundStyle(isOn ? Color(red: 0.2, green: 0.85, blue: 0.47) : .white)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }
}
