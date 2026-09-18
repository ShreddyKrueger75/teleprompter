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
        case .behindGlass: "Beam-splitter rig read from 1-3 m. Large type, mirrored, with room to read ahead."
        }
    }
    /// Fraction of window height where the reading line sits. Leaves room below it to read ahead.
    var guidePosition: CGFloat {
        switch self {
        case .underNotch: 0.20
        case .besideWebcam: 0.28
        case .behindGlass: 0.42
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
        case .behindGlass: 84
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
        // ponytail: `try?` on the enums too, so an unknown case costs that one field, not all of them
        rig = ((try? c.decodeIfPresent(Rig.self, forKey: .rig)) ?? nil) ?? d.rig
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? d.fontSize
        lineSpacing = try c.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? d.lineSpacing
        margin = try c.decodeIfPresent(Double.self, forKey: .margin) ?? d.margin
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? d.opacity
        countdown = try c.decodeIfPresent(Int.self, forKey: .countdown) ?? d.countdown
        theme = ((try? c.decodeIfPresent(Theme.self, forKey: .theme)) ?? nil) ?? d.theme
        mirrorH = try c.decodeIfPresent(Bool.self, forKey: .mirrorH) ?? d.mirrorH
        mirrorV = try c.decodeIfPresent(Bool.self, forKey: .mirrorV) ?? d.mirrorV
        guide = try c.decodeIfPresent(Bool.self, forKey: .guide) ?? d.guide
        hideFromShare = try c.decodeIfPresent(Bool.self, forKey: .hideFromShare) ?? d.hideFromShare
        voice = try c.decodeIfPresent(Bool.self, forKey: .voice) ?? d.voice
        alwaysOnTop = try c.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? d.alwaysOnTop
        // A hand-edited or older blob can hold a size this rig does not allow.
        fontSize = min(max(fontSize, rig.fontRange.lowerBound), rig.fontRange.upperBound)
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
        didSet {
            settings.save()
            // Only touch the audio engine when voice itself changed: this fires on every
            // slider tick otherwise.
            if settings.voice != oldValue.voice { syncVoice() }
            onSettingsChange?()
        }
    }
    var script = UserDefaults.standard.string(forKey: "script") ?? "" {
        didSet {
            UserDefaults.standard.set(script, forKey: "script")
            matcher = WordMatcher(script: script)
            wordCount = matcher.words.count
            // A new script is a new read: never open part-way into it.
            offset = 0
            voiceTarget = 0
            textHeight = 0
        }
    }
    var offset: CGFloat = 0          // pixels the script has scrolled past the reading line
    var playing = false
    var countdownLeft = 0
    /// Height of the script itself, reported by the view. Excludes the end-of-script mark,
    /// because pace is measured against the words.
    var textHeight: CGFloat = 0
    var wordCount = 0
    var onSettingsChange: (() -> Void)?
    /// Mirrors the recogniser so the microphone button redraws when listening starts.
    private(set) var voiceState = VoiceScroll.State.off
    /// Why voice could not run. Cleared as soon as it works.
    var voiceNotice: String?
    /// A hotkey another app already owns. Separate from voice: different cause, different remedy.
    var hotkeyNotice: String?

    var atEnd: Bool { textHeight > 0 && offset >= textHeight }
    var progress: Double { textHeight > 0 ? min(1, max(0, offset / textHeight)) : 0 }

    private var timer: Timer?
    private var last: Date?
    private var matcher = WordMatcher(script: "")
    private var voiceTarget: CGFloat = 0
    private var countdownToken = 0
    private let voice = VoiceScroll()

    init() {
        matcher = WordMatcher(script: script)
        wordCount = matcher.words.count
        voice.onTranscript = { [weak self] t in self?.heard(t) }
        voice.onSessionRestart = { [weak self] in self?.matcher.newSession() }
        voice.onStateChange = { [weak self] state in
            guard let self else { return }
            voiceState = state
            if state == .listening { voiceNotice = nil }
        }
        voice.onUnavailable = { [weak self] reason in
            guard let self else { return }
            settings.voice = false          // never leave the mic looking live when it is not
            voiceNotice = reason
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
        guard settings.countdown > 0 else { start(); return }
        countdownLeft = settings.countdown  // every start gets a countdown, not just from the top
        countdownToken += 1
        tickCountdown(countdownToken)
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
    }

    func pause() {
        countdownToken += 1                 // strands any countdown already in flight
        countdownLeft = 0
        playing = false
        timer?.invalidate()
        timer = nil
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

    /// Applied when the reader picks a rig. Only overrides what the new rig actually
    /// requires, so a hand-tuned size survives a look at the other options.
    func apply(rig: Rig) {
        settings.rig = rig
        if !rig.fontRange.contains(settings.fontSize) {
            settings.fontSize = min(max(settings.fontSize, rig.fontRange.lowerBound), rig.fontRange.upperBound)
        }
        if rig.mirrorsByDefault && !settings.mirrorH { settings.mirrorH = true }
    }

    private func tickCountdown(_ token: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, token == countdownToken, countdownLeft > 0 else { return }
            countdownLeft -= 1
            countdownLeft == 0 ? start() : tickCountdown(token)
        }
    }

    private func step() {
        let now = Date()
        let dt = last.map { now.timeIntervalSince($0) } ?? 0
        last = now
        if voiceState == .listening {
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
        guard settings.voice else { voice.stop(); return }
        // Start listening from where the reader actually is, not from the top.
        seek(to: offset)
        voice.start()
    }

    /// Ask for microphone and speech access when the reader switches voice on,
    /// not in the middle of their first take.
    func prepareVoice() { if settings.voice { syncVoice() } }
}
