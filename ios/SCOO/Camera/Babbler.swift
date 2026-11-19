import Foundation
import AVFoundation

/// How the 모리들 talk out loud: not a reading voice but a soft, cute murmur that sounds like talking. Every syllable of the reply
/// gets its vowel color (ㅏ bright, ㅜ round, ㅣ thin…) and a hint of its consonant (ㅅ hiss, ㄱ click, ㅁ hum), and the syllables flow into each other
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

    /// The consonant a syllable starts with, as a sound shape: what makes it sound like talking.
    enum Onset: Equatable {
        case none
        /// ㄱ ㄷ ㅂ ㅋ ㅌ ㅍ…: a tiny stop, then a soft click.
        case stop
        /// ㅅ ㅈ ㅊ…: a short hiss before the vowel.
        case hiss
        /// ㅎ: a breath.
        case breath
        /// ㄴ ㅁ: a hum.
        case nasal
        /// ㄹ: a quick glide.
        case liquid
    }

    struct Syllable: Equatable {
        var vowel: Vowel
        var onset: Onset = .none
        /// Silence after it, in seconds (spaces and punctuation).
        var pause: Double = 0
        /// Ends a question: the pitch goes up.
        var rising = false
        /// Ends with ~: a sing-song up-and-down.
        var singsong = false
        var loud = false
        /// Has a final consonant (받침): a touch shorter, closing into a hum.
        var closed = false
    }

    /// ㅏ ㅐ ㅑ ㅒ ㅓ ㅔ ㅕ ㅖ ㅗ ㅘ ㅙ ㅚ ㅛ ㅜ ㅝ ㅞ ㅟ ㅠ ㅡ ㅢ ㅣ
    private nonisolated static let medials: [Vowel] = [.a, .e, .a, .e, .o, .e, .o, .e, .o, .a, .e, .e, .o, .u, .o, .e, .i, .u, .u, .i, .i]
    /// ㄱ ㄲ ㄴ ㄷ ㄸ ㄹ ㅁ ㅂ ㅃ ㅅ ㅆ ㅇ ㅈ ㅉ ㅊ ㅋ ㅌ ㅍ ㅎ
    private nonisolated static let initials: [Onset] = [.stop, .stop, .nasal, .stop, .stop, .liquid, .nasal, .stop, .stop,
                                                        .hiss, .hiss, .none, .hiss, .hiss, .hiss, .stop, .stop, .stop, .breath]

    private nonisolated static func onset(ofLetter letter: String) -> Onset? {
        switch letter {
        case "b", "d", "g", "k", "p", "q", "t": return .stop
        case "c", "f", "j", "s", "v", "x", "z": return .hiss
        case "h": return .breath
        case "m", "n": return .nasal
        case "l", "r": return .liquid
        default: return nil
        }
    }

    /// At most this many syllables, so a long reply stays a short murmur.
    nonisolated static let maxSyllables = 48

    nonisolated static func syllables(in text: String) -> [Syllable] {
        var result: [Syllable] = []
        var generator = SeededRandom(seed: text.unicodeScalars.reduce(1469598103934665603) { ($0 ^ UInt64($1.value)) &* 1099511628211 })
        var pendingOnset: Onset = .none
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if (0xAC00...0xD7A3).contains(value) {
                let index = Int(value - 0xAC00)
                result.append(Syllable(vowel: medials[(index / 28) % 21], onset: initials[index / 588], closed: index % 28 != 0))
            } else if CharacterSet.letters.contains(scalar) {
                let letter = Character(scalar).lowercased()
                let vowel: Vowel?
                switch letter {
                case "a": vowel = .a
                case "e": vowel = .e
                case "i", "y": vowel = .i
                case "o": vowel = .o
                case "u", "w": vowel = .u
                default: vowel = nil
                }
                if let vowel {
                    result.append(Syllable(vowel: vowel, onset: pendingOnset))
                    pendingOnset = .none
                } else if let onset = onset(ofLetter: letter) {
                    pendingOnset = onset
                }
                continue
            } else if CharacterSet.decimalDigits.contains(scalar) {
                let initial = initials[Int(generator.next() % 19)]
                result.append(Syllable(vowel: Vowel(rawValue: Int(generator.next() % 5))!, onset: initial))
            } else if !result.isEmpty {
                pendingOnset = .none
                let last = result.count - 1
                switch scalar {
                case " ", "\n": result[last].pause = max(result[last].pause, 0.05)
                case "?": result[last].rising = true; result[last].pause = 0.2
                case "!": result[last].loud = true; result[last].pause = 0.18
                case "~": result[last].singsong = true; result[last].pause = max(result[last].pause, 0.16)
                case ",", ".", "…", "·": result[last].pause = max(result[last].pause, 0.16)
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

    /// (first, second) formant of each vowel in Hz, set a little high so it sounds small and cute.
    private nonisolated static let formants: [Vowel: (Double, Double)] = [
        .a: (920, 1450), .e: (600, 2150), .i: (360, 2650), .o: (600, 1000), .u: (390, 950),
    ]
    /// A closed, humming mouth, for ㄴ ㅁ and 받침.
    private nonisolated static let hum: (Double, Double) = (300, 1300)

    /// The fundamental for a 모리's pitch: a low voice (1.05) is about 300 Hz, a high one (1.5) about 580 Hz.
    nonisolated static func baseFrequency(pitch: Double) -> Double {
        min(640, max(240, 300 + (pitch - 1.05) / 0.45 * 280))
    }

    nonisolated static func render(_ syllables: [Syllable], pitch: Double) -> Speech {
        let rate = sampleRate
        let base = baseFrequency(pitch: pitch)
        // higher voices talk a little faster
        let length = max(0.09, 0.125 - (pitch - 1) * 0.05)
        var generator = SeededRandom(seed: UInt64(syllables.count) &* 7919 &+ UInt64(base))
        var noise = SeededRandom(seed: 0xC0FFEE)

        // One continuous voice per phrase, the way people talk: consonants shape the start of each
        // syllable, pitch and vowel color glide between them, and there is silence only at punctuation.
        var samples: [Float] = []
        var blips: [(time: Double, loudness: Double)] = []
        samples.reserveCapacity(Int(Double(syllables.count) * (length + 0.05) * rate))
        let smoothing = 1 - exp(-1 / (0.014 * rate))
        let fade = 0.03 * rate
        var phrase: [(syllable: Syllable, f0: Double, glide: Double, count: Int, loudness: Double)] = []

        func flush(pause: Double) {
            guard let first = phrase.first else { return }
            let total = phrase.reduce(0) { $0 + $1.count }
            var frequency = first.f0
            var (f1, f2) = formants[first.syllable.vowel]!
            var phase = 0.0
            var vibrato = 0.0
            var previousNoise = 0.0
            var written = 0
            for (position, part) in phrase.enumerated() {
                blips.append((Double(samples.count) / rate, part.loudness))
                let vowel = formants[part.syllable.vowel]!
                let onsetLength = 0.035 * rate
                let isLast = position == phrase.count - 1
                for n in 0..<part.count {
                    let t = Double(n) / Double(part.count)
                    let inOnset = Double(n) < onsetLength
                    let inCoda = part.syllable.closed && t > 0.72

                    // where the mouth is heading right now
                    var target = vowel
                    if inCoda || (inOnset && part.syllable.onset == .nasal) { target = hum }
                    if inOnset && part.syllable.onset == .liquid { target = (vowel.0 * 0.8, 1500) }
                    var targetPitch = part.f0 * (1 + part.glide * t)
                    if part.syllable.singsong { targetPitch *= 1 + 0.12 * sin(.pi * 2 * t) }
                    frequency += (targetPitch - frequency) * smoothing
                    f1 += (target.0 - f1) * smoothing
                    f2 += (target.1 - f2) * smoothing

                    // a little vibrato on long, held syllables
                    vibrato += 2 * .pi * 5.5 / rate
                    let wobble = 1 + (isLast || part.syllable.singsong ? 0.012 : 0.004) * sin(vibrato)
                    phase += 2 * .pi * frequency * wobble / rate
                    var voice = 0.0
                    var harmonic = 1.0
                    while harmonic * frequency < 5200 && harmonic <= 14 {
                        let f = harmonic * frequency
                        let gain = exp(-pow((f - f1) / 190, 2)) + 0.6 * exp(-pow((f - f2) / 270, 2)) + 0.04
                        voice += gain / pow(harmonic, 0.75) * sin(harmonic * phase)
                        harmonic += 1
                    }

                    // the consonant: how loud the voice is and how much breath/hiss is mixed in
                    let white = noise.unit() * 2 - 1
                    let bright = white - previousNoise   // crude high-pass for a hiss
                    previousNoise = white
                    var voiceLevel = 1.0
                    var air = 0.025 * white              // a touch of breath always, for a soft voice
                    let onsetT = Double(n) / onsetLength
                    switch inOnset ? part.syllable.onset : Onset.none {
                    case .stop:
                        voiceLevel = onsetT < 0.45 ? 0.08 : 0.08 + 0.92 * (onsetT - 0.45) / 0.55
                        if onsetT >= 0.45 && onsetT < 0.62 { air += 0.35 * bright }
                    case .hiss:
                        voiceLevel = 0.12 + 0.88 * pow(onsetT, 2)
                        air += 0.30 * bright * (1 - onsetT)
                    case .breath:
                        voiceLevel = 0.35 + 0.65 * onsetT
                        air += 0.18 * white * (1 - onsetT)
                    case .nasal:
                        voiceLevel = 0.65 + 0.35 * onsetT
                    case .liquid:
                        voiceLevel = 0.8 + 0.2 * onsetT
                    case .none:
                        break
                    }
                    if inCoda { voiceLevel *= 0.7 }

                    let index = Double(written)
                    let edges = min(1, index / fade, Double(total - written) / fade)
                    let syllableShape = 0.7 + 0.3 * sin(.pi * t)
                    samples.append(Float((voice * voiceLevel * 0.9 + air * 3) * edges * syllableShape * part.loudness))
                    written += 1
                }
            }
            phrase = []
            samples.append(contentsOf: repeatElement(0, count: Int(pause * rate)))
        }

        for (position, syllable) in syllables.enumerated() {
            let progress = syllables.count > 1 ? Double(position) / Double(syllables.count - 1) : 0
            let endsPhrase = syllable.pause >= 0.1 || position == syllables.count - 1
            // a gentle fall over the sentence, a lift at the start of each phrase, and a slight wobble
            let startsPhrase = position == 0 || syllables[position - 1].pause >= 0.1
            var f0 = base * (1.04 - 0.08 * progress) * (startsPhrase ? 1.05 : 1) * (1 + (generator.unit() - 0.5) * 0.05)
            var glide = endsPhrase ? -0.05 : 0.0
            if syllable.rising { f0 *= 1.1; glide = 0.22 }
            let duration = length * (syllable.closed ? 0.92 : 1) * (0.94 + generator.unit() * 0.12)
                * (endsPhrase ? 1.45 : 1) * (syllable.rising ? 1.15 : 1) + min(syllable.pause, 0.06) * 0.5
            let loudness = syllable.loud ? 1.0 : (endsPhrase ? 0.8 : 0.88)
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
