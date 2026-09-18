import Foundation

/// Tracks how far through the script the speaker is, from a running speech transcript.
struct WordMatcher {
    let words: [String]
    private(set) var position = 0   // index of the next unspoken script word
    private var consumed = 0        // transcript words already matched

    init(script: String) { words = WordMatcher.tokens(script) }

    static func tokens(_ s: String) -> [String] {
        s.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    var fraction: Double { words.isEmpty ? 0 : Double(position) / Double(words.count) }

    /// Feed the full transcript of the current recognition session; only the new tail is examined.
    mutating func feed(transcript: String) {
        let heard = WordMatcher.tokens(transcript)
        guard heard.count > consumed else { return }
        for w in heard[consumed...] {
            // ponytail: 12-word look-ahead skips fillers and misreads; no fuzzy matching
            if let hit = (position..<min(position + 12, words.count)).first(where: { words[$0] == w }) {
                position = hit + 1
            }
        }
        consumed = heard.count
    }

    /// Call when the recognizer starts a fresh session (its transcript restarts from empty).
    mutating func newSession() { consumed = 0 }

    /// Move the match position to a fraction of the script, after the reader scrubs or jumps,
    /// so voice picks up from where they actually are rather than dragging them back.
    mutating func seek(fraction f: Double) {
        position = min(words.count, max(0, Int((Double(words.count) * f).rounded())))
    }

    mutating func reset() { position = 0; consumed = 0 }
}
