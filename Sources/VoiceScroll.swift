import AVFoundation
import Speech

/// On-device speech recognition that streams the running transcript to `onTranscript`.
/// Every failure path reports back, so the microphone button never claims to be listening
/// when it is not.
@MainActor
final class VoiceScroll {
    enum State: Equatable { case off, starting, listening, failed }

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer() ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private(set) var state = State.off
    var onTranscript: ((String) -> Void)?
    var onSessionRestart: (() -> Void)?
    /// Called with a reader-facing reason when voice cannot run.
    var onUnavailable: ((String) -> Void)?

    private var wantsToRun: Bool { state == .starting || state == .listening }

    func start() {
        guard state == .off || state == .failed else { return }
        state = .starting
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard self.wantsToRun else { return }
                switch status {
                case .authorized: self.requestMicrophone()
                case .denied:
                    self.fail("Teleprompter needs speech recognition to scroll by voice. Turn it on in System Settings > Privacy & Security > Speech Recognition.")
                case .restricted:
                    self.fail("Speech recognition is restricted on this Mac, so voice scrolling is unavailable.")
                default:
                    self.fail("Speech recognition was not allowed, so voice scrolling is off.")
                }
            }
        }
    }

    private func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in
                guard self.wantsToRun else { return }
                guard granted else {
                    self.fail("Teleprompter needs the microphone to scroll by voice. Turn it on in System Settings > Privacy & Security > Microphone.")
                    return
                }
                self.beginSession()
            }
        }
    }

    func stop() {
        state = .off
        endSession()
    }

    private func fail(_ reason: String) {
        state = .failed
        endSession()
        onUnavailable?(reason)
    }

    private func beginSession() {
        guard wantsToRun else { return }
        // audio never leaves the Mac: no on-device model, no voice scroll
        guard let recognizer, recognizer.isAvailable else {
            fail("Speech recognition is not available right now, so voice scrolling is off.")
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            fail("This Mac has no on-device speech model for \(recognizer.locale.identifier), and Teleprompter never sends audio off your Mac. Add the language in System Settings > Keyboard > Dictation to use voice scrolling.")
            return
        }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true
        request = req
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            fail("No microphone input is available, so voice scrolling is off.")
            return
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in req.append(buffer) }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            fail("The microphone could not be started: \(error.localizedDescription)")
            return
        }
        onSessionRestart?()
        state = .listening
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result { self.onTranscript?(result.bestTranscription.formattedString) }
                if error != nil || result?.isFinal == true {
                    // ponytail: sessions end after ~1 min or on silence; just open another
                    guard self.wantsToRun else { return }
                    self.endSession()
                    self.state = .starting
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.beginSession() }
                }
            }
        }
    }

    private func endSession() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
