import SwiftUI
import Observation

enum Theme: String, Codable, CaseIterable {
    // ponytail: raw values are storage keys, never shown; renaming `name` must not reset settings
    case whiteOnBlack, yellowOnBlack, blackOnWhite

    var name: String {
        switch self {
        case .whiteOnBlack: "White on black"
        case .yellowOnBlack: "Yellow on black"
        case .blackOnWhite: "Black on white"
        }
    }
    var fg: Color { self == .blackOnWhite ? .black : self == .yellowOnBlack ? .yellow : .white }
    var bg: Color { self == .blackOnWhite ? .white : .black }
    /// Marker colour that keeps contrast against this theme's background.
    var marker: Color { self == .blackOnWhite ? Color(red: 0.05, green: 0.45, blue: 0.2) : Color(red: 0.2, green: 0.85, blue: 0.47) }
}

/// Where the camera is. Sets the reading line, how large type can go, and mirroring.
enum Rig: String, Codable, CaseIterable {
    case underNotch, besideWebcam, behindGlass

    var name: String {
        switch self {
        case .underNotch: "Under the notch"
        case .besideWebcam: "Beside a webcam"
        case .behindGlass: "Behind glass"
        }
    }
    var detail: String {
        switch self {
        case .underNotch: "Small window just below a built-in camera. Reading line near the top."
        case .besideWebcam: "Window near a webcam on a monitor, read from arm's length."
        case .behindGlass: "Beam-splitter rig read from 1-3 m. Centred line, large type, mirrored."
        }
    }
    /// Fraction of window height where the reading line sits.
    var guidePosition: CGFloat {
        switch self {
        case .underNotch: 0.20
        case .besideWebcam: 0.28
        case .behindGlass: 0.50
        }
    }
    var fontRange: ClosedRange<Double> {
        switch self {
        case .underNotch: 14...96
        case .besideWebcam: 16...140
        case .behindGlass: 24...240
        }
    }
    var suggestedFontSize: Double {
        switch self {
        case .underNotch: 28
        case .besideWebcam: 44
        case .behindGlass: 110
        }
    }
    var mirrorsByDefault: Bool { self == .behindGlass }
}

// ponytail: decoded field by field so a new setting never invalidates a saved blob
struct Settings: Codable {
    var wpm = 140.0          // reading pace; pixel speed is derived from it
    var rig = Rig.underNotch
    var fontSize = 28.0
    var lineSpacing = 1.5    // multiplier of font size
    var margin = 24.0
    var opacity = 1.0        // background only; script text always stays fully opaque
    var countdown = 3
    var theme = Theme.whiteOnBlack
    var mirrorH = false
    var mirrorV = false
    var guide = true
    var hideFromShare = true
    var voice = false
    var alwaysOnTop = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        wpm = try c.decodeIfPresent(Double.self, forKey: .wpm) ?? d.wpm
        rig = try c.decodeIfPresent(Rig.self, forKey: .rig) ?? d.rig
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? d.fontSize
        lineSpacing = try c.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? d.lineSpacing
        margin = try c.decodeIfPresent(Double.self, forKey: .margin) ?? d.margin
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? d.opacity
        countdown = try c.decodeIfPresent(Int.self, forKey: .countdown) ?? d.countdown
        theme = try c.decodeIfPresent(Theme.self, forKey: .theme) ?? d.theme
        mirrorH = try c.decodeIfPresent(Bool.self, forKey: .mirrorH) ?? d.mirrorH
        mirrorV = try c.decodeIfPresent(Bool.self, forKey: .mirrorV) ?? d.mirrorV
        guide = try c.decodeIfPresent(Bool.self, forKey: .guide) ?? d.guide
        hideFromShare = try c.decodeIfPresent(Bool.self, forKey: .hideFromShare) ?? d.hideFromShare
        voice = try c.decodeIfPresent(Bool.self, forKey: .voice) ?? d.voice
        alwaysOnTop = try c.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? d.alwaysOnTop
    }

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
        didSet {
            UserDefaults.standard.set(script, forKey: "script")
            matcher = WordMatcher(script: script)
            wordCount = matcher.words.count
        }
    }
    var offset: CGFloat = 0          // pixels the script has scrolled past the reading line
    var playing = false
    var countdownLeft = 0
    var textHeight: CGFloat = 0      // laid-out script height, reported by the view
    var wordCount = 0
    var onSettingsChange: (() -> Void)?
    /// Set when the reader needs to be told something, e.g. voice was refused.
    var notice: String?

    var voiceState: VoiceScroll.State { voice.state }
    /// True once the last line has cleared the reading line.
    var atEnd: Bool { textHeight > 0 && offset >= textHeight }
    var progress: Double { textHeight > 0 ? min(1, max(0, offset / textHeight)) : 0 }

    private var timer: Timer?
    private var last: Date?
    private var matcher = WordMatcher(script: "")
    private var voiceTarget: CGFloat = 0
    private let voice = VoiceScroll()

    init() {
        matcher = WordMatcher(script: script)
        wordCount = matcher.words.count
        voice.onTranscript = { [weak self] t in self?.heard(t) }
        voice.onSessionRestart = { [weak self] in self?.matcher.newSession() }
        voice.onUnavailable = { [weak self] reason in
            guard let self else { return }
            settings.voice = false          // never leave the mic looking live when it is not
            notice = reason
        }
    }

    /// Reading pace drives everything, so changing font size or window width
    /// never changes how long the script takes to read.
    var pxPerSec: CGFloat {
        guard wordCount > 0, textHeight > 0, settings.wpm > 0 else { return 0 }
        return textHeight * settings.wpm / (Double(wordCount) * 60)
    }
    var duration: Double { wordCount > 0 ? Double(wordCount) / settings.wpm * 60 : 0 }
    var elapsed: Double { duration * progress }

    func togglePlay() { playing || countdownLeft > 0 ? pause() : play() }

    func play() {
        if atEnd { restart() }              // the read is over; play means "go again"
        guard settings.countdown > 0, countdownLeft == 0 else { start(); return }
        countdownLeft = settings.countdown  // every start gets a countdown, not just from the top
        tickCountdown()
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

    func jumpBack(seconds: Double = 5) { seek(to: offset - pxPerSec * seconds) }
    func jumpForward(seconds: Double = 5) { seek(to: offset + pxPerSec * seconds) }

    /// Move to a pixel offset and bring the voice matcher along, so voice does not drag it back.
    func seek(to newOffset: CGFloat) {
        offset = min(max(0, newOffset), max(0, textHeight))
        voiceTarget = offset
        matcher.seek(fraction: progress)
    }

    func adjustWPM(_ delta: Double) {
        settings.wpm = min(240, max(60, (settings.wpm + delta).rounded()))
    }

    /// Applied when the reader picks a rig, so the preset actually changes something.
    func apply(rig: Rig) {
        settings.rig = rig
        settings.fontSize = min(max(rig.suggestedFontSize, rig.fontRange.lowerBound), rig.fontRange.upperBound)
        settings.mirrorH = rig.mirrorsByDefault
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
        if voice.state == .listening {
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
        settings.voice ? voice.start() : voice.stop()
    }

    /// Ask for microphone and speech access when the reader switches voice on,
    /// not in the middle of their first take.
    func prepareVoice() { if settings.voice { voice.start() } }
}
