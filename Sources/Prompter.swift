import SwiftUI
import Observation

enum Theme: String, Codable, CaseIterable {
    case whiteOnBlack = "White on black"
    case yellowOnBlack = "Yellow on black"
    case blackOnWhite = "Black on white"

    var fg: Color { self == .blackOnWhite ? .black : self == .yellowOnBlack ? .yellow : .white }
    var bg: Color { self == .blackOnWhite ? .white : .black }
}

// ponytail: stored as one JSON blob; adding a field later needs a default via init(from:) or the
// old blob fails to decode and settings reset.
struct Settings: Codable {
    var speed = 1.0          // 1.0x = 30 px/s
    var fontSize = 28.0
    var lineSpacing = 1.5    // multiplier of font size
    var margin = 24.0
    var opacity = 1.0
    var countdown = 3
    var theme = Theme.whiteOnBlack
    var mirrorH = false
    var mirrorV = false
    var guide = true
    var hideFromShare = true
    var voice = false
    var alwaysOnTop = true

    static func load() -> Settings {
        UserDefaults.standard.data(forKey: "settings")
            .flatMap { try? JSONDecoder().decode(Settings.self, from: $0) } ?? Settings()
    }
    func save() { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: "settings") }
}

@Observable @MainActor
final class Prompter {
    var settings = Settings.load() {
        didSet { settings.save(); syncVoice(); onSettingsChange?() }
    }
    var script = UserDefaults.standard.string(forKey: "script") ?? "" {
        didSet { UserDefaults.standard.set(script, forKey: "script"); matcher = WordMatcher(script: script) }
    }
    var offset: CGFloat = 0          // pixels scrolled past the reading line
    var playing = false
    var countdownLeft = 0
    var textHeight: CGFloat = 0      // laid-out script height, reported by the view
    var onSettingsChange: (() -> Void)?

    private var timer: Timer?
    private var last: Date?
    private var matcher = WordMatcher(script: "")
    private var voiceTarget: CGFloat = 0
    private let voice = VoiceScroll()

    init() {
        matcher = WordMatcher(script: script)
        voice.onTranscript = { [weak self] t in self?.heard(t) }
        voice.onSessionRestart = { [weak self] in self?.matcher.newSession() }
    }

    var pxPerSec: CGFloat { 30 * settings.speed }
    var duration: Double { pxPerSec > 0 ? textHeight / pxPerSec : 0 }
    var elapsed: Double { pxPerSec > 0 ? offset / pxPerSec : 0 }

    func togglePlay() { playing || countdownLeft > 0 ? pause() : play() }

    func play() {
        if settings.countdown > 0 && offset == 0 && countdownLeft == 0 {
            countdownLeft = settings.countdown
            tickCountdown()
            return
        }
        start()
    }

    private func start() {
        playing = true
        last = nil
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.step() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        syncVoice()
    }

    func pause() {
        countdownLeft = 0
        playing = false
        timer?.invalidate()
        timer = nil
        syncVoice()
    }

    func restart() {
        pause()
        offset = 0
        voiceTarget = 0
        matcher.reset()
    }

    func jumpBack(seconds: Double = 5) {
        offset = max(0, offset - pxPerSec * seconds)
        voiceTarget = offset   // ponytail: voice re-syncs on the next matched word
    }

    func adjustSpeed(_ delta: Double) {
        settings.speed = (min(3, max(0.2, settings.speed + delta)) * 10).rounded() / 10
    }

    private func tickCountdown() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, countdownLeft > 0 else { return }
            countdownLeft -= 1
            countdownLeft == 0 ? start() : tickCountdown()
        }
    }

    private func step() {
        let now = Date()
        let dt = last.map { now.timeIntervalSince($0) } ?? 0
        last = now
        if voice.running {
            offset += (voiceTarget - offset) * min(1, dt * 3)   // ease toward the spoken position
        } else {
            offset += pxPerSec * dt
        }
        if offset >= textHeight && textHeight > 0 {
            offset = textHeight
            pause()
        }
    }

    private func heard(_ transcript: String) {
        matcher.feed(transcript: transcript)
        // ponytail: maps word fraction to pixel height; exact per-line mapping if it drifts
        voiceTarget = CGFloat(matcher.fraction) * textHeight
    }

    private func syncVoice() {
        settings.voice && playing ? voice.start() : voice.stop()
    }
}
