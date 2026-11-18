import Foundation
import AVFoundation
import Speech

/// Voice talk mode (음성 대화, 티키타카): listens with on-device speech recognition, asks the server (or the
/// built-in lines) for a short reply, says it out loud, then listens again. `level` (0...1) drives the
/// equalizer around the frame: the microphone while listening, the friend's voice while speaking.
@MainActor
final class PetTalkSession: NSObject, ObservableObject {
    enum Phase: Equatable { case off, starting, listening, thinking, speaking }

    @Published private(set) var phase: Phase = .off
    @Published private(set) var level: Double = 0
    /// What the recogniser has heard so far in this turn.
    @Published private(set) var heard = ""
    /// The friend's last line, shown in its speech bubble.
    @Published private(set) var reply = ""
    /// The friend's face while it speaks.
    @Published private(set) var mood: MoriExpression = .normal
    /// Why talk mode could not start or stopped (permission, no recogniser).
    @Published var problem: String?

    var isOn: Bool { phase != .off }

    /// Ask the server for replies (text only). Off: only the built-in lines.
    var useServer = true

    private var pet = TalkPet.of(nil, moriName: "모리", personality: "다정함")
    private var history: [TalkTurn] = []
    /// The phone's own model, when it has one (free, nothing leaves the phone).
    private let onDevice = OnDeviceReplies()
    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()
    private var silenceTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var decayTask: Task<Void, Never>?
    private var turn = 0
    /// Each listening round has its own id, so the callback of a cancelled round cannot restart listening.
    private var round = 0

    /// A pause this long after speech ends the turn.
    nonisolated static let endOfTurn: Duration = .milliseconds(1100)
    /// Talk mode closes itself after this long without hearing anything.
    nonisolated static let idleLimit: Duration = .seconds(30)
    /// Wait this long for the server before falling back to the built-in lines.
    nonisolated static let serverWait: Duration = .seconds(6)

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: On and off

    func start(_ pet: TalkPet) async {
        guard phase == .off else { return }
        self.pet = pet
        problem = nil
        phase = .starting
        guard await Self.allowed() else {
            problem = "설정에서 마이크와 음성 인식을 허용하면 \(pet.name)랑 이야기할 수 있어요."
            phase = .off
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            problem = "지금은 한국어 음성 인식을 쓸 수 없어요. 잠시 뒤에 다시 해 주세요."
            phase = .off
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
            try session.setActive(true)
        } catch {
            problem = "마이크를 켜지 못했어요."
            phase = .off
            return
        }
        guard phase == .starting else { return }   // stopped while asking for permission
        history = []
        reply = ""
        onDevice.reset()
        listen()
    }

    /// Updates who is talking (the friend picked in the menu can change mid-conversation).
    func update(_ pet: TalkPet) { self.pet = pet }

    func stop() {
        guard phase != .off else { return }
        phase = .off
        turn += 1
        stopListening()
        synthesizer.stopSpeaking(at: .immediate)
        silenceTask?.cancel(); idleTask?.cancel(); decayTask?.cancel()
        level = 0
        heard = ""
        mood = .normal
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func allowed() async -> Bool {
        let speech: Bool = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    // MARK: Listening

    /// `resetIdle` false keeps the running quiet-time clock (restarts after "no speech" must not extend it).
    private func listen(resetIdle: Bool = true) {
        guard phase != .off else { return }
        stopListening()
        heard = ""
        mood = .normal
        phase = .listening
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        // Keep the voice on the phone when the device can recognise Korean by itself.
        if recognizer?.supportsOnDeviceRecognition == true { request.requiresOnDeviceRecognition = true }
        self.request = request

        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0),
                         block: Self.tap(request: request) { [weak self] value in
            Task { @MainActor in self?.hear(level: value) }
        })
        engine.prepare()
        do { try engine.start() } catch {
            problem = "마이크를 켜지 못했어요."
            stop()
            return
        }
        round += 1
        let current = round
        recognition = recognizer?.recognitionTask(with: request, resultHandler: Self.results { [weak self] text, final, failed in
            Task { @MainActor in self?.recognized(text, final: final, failed: failed, round: current) }
        })
        guard resetIdle || idleTask == nil else { return }
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.idleLimit)
            guard !Task.isCancelled, let self, self.phase == .listening, self.heard.isEmpty else { return }
            self.stop()
        }
    }

    private func stopListening() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognition?.cancel()
        request = nil
        recognition = nil
        silenceTask?.cancel()
    }

    /// Built outside the main actor: the audio thread calls it.
    nonisolated private static func tap(request: SFSpeechAudioBufferRecognitionRequest,
                                        level: @escaping @Sendable (Double) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            level(Self.loudness(buffer))
        }
    }

    nonisolated private static func results(_ handle: @escaping @Sendable (String?, Bool, Bool) -> Void)
        -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in handle(result?.bestTranscription.formattedString, result?.isFinal ?? false, error != nil) }
    }

    /// Microphone loudness mapped to 0...1 (about -50 dB to -10 dB).
    nonisolated static func loudness(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
        let rms = sqrt(sum / Float(buffer.frameLength))
        let decibels = 20 * log10(max(rms, 0.000_01))
        return Double(min(1, max(0, (decibels + 50) / 40)))
    }

    private func hear(level value: Double) {
        guard phase == .listening else { return }
        // quick to rise, slow to fall, like a level meter
        level = value > level ? value : level * 0.82 + value * 0.18
    }

    private func recognized(_ text: String?, final: Bool, failed: Bool, round current: Int) {
        guard current == round, phase == .listening else { return }
        if let text, !text.isEmpty {
            heard = text
            idleTask?.cancel(); idleTask = nil
            silenceTask?.cancel()
            silenceTask = Task { [weak self] in
                try? await Task.sleep(for: Self.endOfTurn)
                guard !Task.isCancelled else { return }
                self?.finishTurn()
            }
        }
        if final { finishTurn() }
        else if failed {
            // "No speech" and similar: keep listening unless something was heard.
            if heard.isEmpty {
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(300))
                    guard let self, current == self.round, self.phase == .listening else { return }
                    self.listen(resetIdle: false)
                }
            }
            else { finishTurn() }
        }
    }

    // MARK: Replying

    private func finishTurn() {
        guard phase == .listening else { return }
        let said = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty else { listen(); return }
        stopListening()
        phase = .thinking
        level = 0
        turn += 1
        let current = turn
        Task {
            let answer = await reply(to: said)
            guard current == turn, phase == .thinking else { return }
            history.append(TalkTurn(me: said, pet: answer.text))
            history = Array(history.suffix(6))
            speak(answer)
        }
    }

    private func reply(to text: String) async -> TalkReply {
        if let answer = await onDevice.reply(to: text, pet: pet) { return answer }
        if useServer && SupabaseConfig.isConfigured, let answer = await serverReply(to: text) { return answer }
        return LocalReplies.reply(to: text, roll: Double.random(in: 0..<1))
    }

    private func serverReply(to text: String) async -> TalkReply? {
        let body: [String: Any] = [
            "pet": pet.name, "kind": pet.kind, "personality": pet.personality, "text": text,
            "history": history.map { ["me": $0.me, "pet": $0.pet] },
        ]
        return await withTaskGroup(of: TalkReply?.self) { group in
            group.addTask {
                guard let data = try? await SupabaseClient.shared.invoke("pet-chat", body) else { return nil }
                struct Answer: Decodable { let reply: String; let mood: String? }
                guard let answer = try? JSONDecoder().decode(Answer.self, from: data), !answer.reply.isEmpty else { return nil }
                return TalkReply(answer.reply, TalkReply.mood(named: answer.mood))
            }
            group.addTask {
                try? await Task.sleep(for: Self.serverWait)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: Speaking

    private func speak(_ answer: TalkReply) {
        reply = answer.text
        mood = answer.mood
        phase = .speaking
        let utterance = AVSpeechUtterance(string: answer.text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.pitchMultiplier = pet.pitch
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.02
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
        decayTask?.cancel()
        decayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, self.phase == .speaking else { return }
                self.level *= 0.86
            }
        }
    }

    private func spokeWord() {
        guard phase == .speaking else { return }
        level = Double.random(in: 0.55...0.95)
    }

    private func doneSpeaking() {
        guard phase == .speaking else { return }
        decayTask?.cancel()
        level = 0
        let current = turn
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, current == self.turn, self.phase == .speaking else { return }
            self.listen()
        }
    }
}

extension PetTalkSession: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        Task { @MainActor in self.spokeWord() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.doneSpeaking() }
    }
}
