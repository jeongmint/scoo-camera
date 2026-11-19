import Foundation
import AVFoundation

/// How the 모리들 talk out loud: not a reading voice but a soft, cute murmur. Every syllable of the reply
/// gets that syllable's vowel color (ㅏ bright, ㅜ round, ㅣ thin…), and the syllables flow into each other
/// in one smooth voice, pausing only at punctuation. Each 모리 has its own pitch, so they all sound different.
/// Everything is synthesized here; there are no sound files.
@MainActor
final class Babbler {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Babbler.sampleRate, channels: 1)!
    private var job: Task<Void, Never>?

    nonisolated static let sampleRate: Double = 44_100

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// Babbles `text`. `beat` is called as each blip starts (with its loudness 0...1), `done` once at the end.
    /// `pitch` is the 모리's voice pitch from `TalkPet` (about 1...1.5).
    func say(_ text: String, pitch: Float, beat: @escaping (Double) -> Void, done: @escaping () -> Void) {
        stop()
        let speech = Self.render(Self.syllables(in: text), pitch: Double(pitch))
        guard speech.duration > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(speech.samples.count)) else {
            done(); return
        }
        buffer.frameLength = buffer.frameCapacity
        speech.samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: source.count)
        }
        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            done(); return
        }
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
        let began = ContinuousClock.now
        job = Task { [weak self] in
            for blip in speech.blips {
                try? await Task.sleep(until: began + .milliseconds(Int(blip.time * 1000)), clock: .continuous)
                guard !Task.isCancelled else { return }
                beat(blip.loudness)
            }
            try? await Task.sleep(until: began + .milliseconds(Int(speech.duration * 1000) + 60), clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.player.stop()
            done()
        }
    }

    func stop() {
        job?.cancel()
        job = nil
        player.stop()
    }

    // MARK: Text to syllables

    enum Vowel: Int { case a, e, i, o, u }

    struct Syllable: Equatable {
        var vowel: Vowel
        /// Silence after it, in seconds (spaces and punctuation).
        var pause: Double = 0
        /// Ends a question: the pitch goes up.
        var rising = false
        var loud = false
        /// Has a final consonant (받침): a touch shorter.
        var closed = false
    }

    /// ㅏ ㅐ ㅑ ㅒ ㅓ ㅔ ㅕ ㅖ ㅗ ㅘ ㅙ ㅚ ㅛ ㅜ ㅝ ㅞ ㅟ ㅠ ㅡ ㅢ ㅣ
    private nonisolated static let medials: [Vowel] = [.a, .e, .a, .e, .o, .e, .o, .e, .o, .a, .e, .e, .o, .u, .o, .e, .i, .u, .u, .i, .i]

    /// At most this many blips, so a long reply stays a short babble.
    nonisolated static let maxSyllables = 48

    nonisolated static func syllables(in text: String) -> [Syllable] {
        var result: [Syllable] = []
        var generator = SeededRandom(seed: text.unicodeScalars.reduce(1469598103934665603) { ($0 ^ UInt64($1.value)) &* 1099511628211 })
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if (0xAC00...0xD7A3).contains(value) {
                let index = Int(value - 0xAC00)
                result.append(Syllable(vowel: medials[(index / 28) % 21], closed: index % 28 != 0))
            } else if CharacterSet.letters.contains(scalar) {
                switch Character(scalar).lowercased() {
                case "a": result.append(Syllable(vowel: .a))
                case "e": result.append(Syllable(vowel: .e))
                case "i", "y": result.append(Syllable(vowel: .i))
                case "o": result.append(Syllable(vowel: .o))
                case "u", "w": result.append(Syllable(vowel: .u))
                default: continue   // consonants ride along with the vowels
                }
            } else if CharacterSet.decimalDigits.contains(scalar) {
                result.append(Syllable(vowel: Vowel(rawValue: Int(generator.next() % 5))!))
            } else if !result.isEmpty {
                switch scalar {
                case " ", "\n": result[result.count - 1].pause = max(result[result.count - 1].pause, 0.05)
                case "?": result[result.count - 1].rising = true; result[result.count - 1].pause = 0.18
                case "!": result[result.count - 1].loud = true; result[result.count - 1].pause = 0.16
                case ",", ".", "~", "…", "·": result[result.count - 1].pause = max(result[result.count - 1].pause, 0.15)
                default: continue
                }
            }
            if result.count >= maxSyllables { break }
        }
        return result
    }

    // MARK: Syllables to sound

    struct Speech {
        var samples: [Float]
        var blips: [(time: Double, loudness: Double)]
        var duration: Double { Double(samples.count) / Babbler.sampleRate }
    }

    /// (first, second) formant of each vowel in Hz, nudged up a little to sound small and cute.
    private nonisolated static let formants: [Vowel: (Double, Double)] = [
        .a: (900, 1400), .e: (580, 2100), .i: (340, 2600), .o: (580, 980), .u: (370, 900),
    ]

    /// The fundamental for a 모리's pitch: a low voice (1.05) is about 300 Hz, a high one (1.5) about 580 Hz.
    nonisolated static func baseFrequency(pitch: Double) -> Double {
        min(640, max(240, 300 + (pitch - 1.05) / 0.45 * 280))
    }

    nonisolated static func render(_ syllables: [Syllable], pitch: Double) -> Speech {
        let rate = sampleRate
        let base = baseFrequency(pitch: pitch)
        // higher voices talk a little faster
        let length = max(0.075, 0.105 - (pitch - 1) * 0.04)
        var generator = SeededRandom(seed: UInt64(syllables.count) &* 7919 &+ UInt64(base))

        // One continuous voice per phrase: the syllables flow into each other (pitch and vowel color glide,
        // the loudness only dips between them), and there is silence only at punctuation.
        var samples: [Float] = []
        var blips: [(time: Double, loudness: Double)] = []
        samples.reserveCapacity(Int(Double(syllables.count) * (length + 0.04) * rate))
        let smoothing = 1 - exp(-1 / (0.018 * rate))
        let fade = 0.025 * rate
        var phrase: [(syllable: Syllable, f0: Double, glide: Double, count: Int, loudness: Double)] = []

        func flush(pause: Double) {
            guard let first = phrase.first else { return }
            let total = phrase.reduce(0) { $0 + $1.count }
            var frequency = first.f0
            var (f1, f2) = formants[first.syllable.vowel]!
            var phase = 0.0
            var written = 0
            for part in phrase {
                blips.append((Double(samples.count) / rate, part.loudness))
                let (t1, t2) = formants[part.syllable.vowel]!
                for n in 0..<part.count {
                    let t = Double(n) / Double(part.count)
                    frequency += (part.f0 * (1 + part.glide * t) - frequency) * smoothing
                    f1 += (t1 - f1) * smoothing
                    f2 += (t2 - f2) * smoothing
                    phase += 2 * .pi * frequency / rate
                    var value = 0.0
                    var harmonic = 1.0
                    while harmonic * frequency < 5000 && harmonic <= 14 {
                        let f = harmonic * frequency
                        let gain = exp(-pow((f - f1) / 200, 2)) + 0.6 * exp(-pow((f - f2) / 280, 2)) + 0.05
                        value += gain / pow(harmonic, 0.7) * sin(harmonic * phase)
                        harmonic += 1
                    }
                    let index = Double(written)
                    let edges = min(1, index / fade, Double(total - written) / fade)
                    let syllableShape = 0.62 + 0.38 * sin(.pi * t)
                    samples.append(Float(value * edges * syllableShape * part.loudness))
                    written += 1
                }
            }
            phrase = []
            samples.append(contentsOf: repeatElement(0, count: Int(pause * rate)))
        }

        for (position, syllable) in syllables.enumerated() {
            let progress = syllables.count > 1 ? Double(position) / Double(syllables.count - 1) : 0
            // a gentle fall over the sentence and only a slight wobble, so it sounds like talking
            var f0 = base * (1.03 - 0.07 * progress) * (1 + (generator.unit() - 0.5) * 0.06)
            var glide = 0.0
            if syllable.rising { f0 *= 1.12; glide = 0.18 }
            let duration = length * (syllable.closed ? 0.9 : 1) * (0.95 + generator.unit() * 0.1)
                * (syllable.rising ? 1.4 : 1) + min(syllable.pause, 0.06) * 0.5
            let loudness = syllable.loud ? 1.0 : 0.85
            phrase.append((syllable, f0, glide, Int(duration * rate), loudness))
            // spaces only stretch the syllable a touch; punctuation is a real breath
            if syllable.pause >= 0.1 { flush(pause: syllable.pause) }
        }
        flush(pause: 0)

        let peak = samples.reduce(Float(0.0001)) { max($0, abs($1)) }
        let scale = 0.32 / peak
        return Speech(samples: samples.map { $0 * scale }, blips: blips)
    }
}

/// Small deterministic random numbers, so the same line always babbles the same way.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
    mutating func unit() -> Double { Double(next() % 10_000) / 10_000 }
}
