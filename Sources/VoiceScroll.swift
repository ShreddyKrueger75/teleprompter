import AVFoundation
import Speech

/// On-device speech recognition that streams the running transcript to `onTranscript`.
@MainActor
final class VoiceScroll {
    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer() ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private(set) var running = false
    var onTranscript: ((String) -> Void)?
    var onSessionRestart: (() -> Void)?

    func start() {
        guard !running else { return }
        running = true
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized, self.running else { self.running = false; return }
                self.beginSession()
            }
        }
    }

    func stop() {
        running = false
        endSession()
    }

    private func beginSession() {
        // audio never leaves the Mac: no on-device model, no voice scroll
        guard running, let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { stop(); return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true
        request = req
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            req.append(buffer)
        }
        engine.prepare()
        do { try engine.start() } catch { stop(); return }
        onSessionRestart?()
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result { self.onTranscript?(result.bestTranscription.formattedString) }
                if error != nil || result?.isFinal == true {
                    // ponytail: sessions end after ~1 min or on silence; just open another
                    self.endSession()
                    if self.running {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.beginSession() }
                    }
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
