// ============================================================================
// SpeechOutput.swift — On-device TTS via AVSpeechSynthesizer
// ============================================================================

@preconcurrency import AVFAudio
import Foundation
import SayItDevCLI

private final class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
        onFinish = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?()
        onFinish = nil
    }
}

enum SpeechOutput {
    private static let delegate = SpeechSynthesizerDelegate()
    private nonisolated(unsafe) static var synthesizer: AVSpeechSynthesizer = {
        let s = AVSpeechSynthesizer()
        s.delegate = delegate
        return s
    }()

    @MainActor
    static func resolveVoice(config: VoiceConfig) async -> AVSpeechSynthesisVoice? {
        if config.voiceName?.lowercased() == "personal" {
            await withCheckedContinuation { cont in
                AVSpeechSynthesizer.requestPersonalVoiceAuthorization { _ in cont.resume() }
            }
            return AVSpeechSynthesisVoice.speechVoices().first {
                $0.voiceTraits.contains(.isPersonalVoice)
            }
        }
        if let name = config.voiceName, !name.isEmpty, name.lowercased() != "default" {
            if let v = AVSpeechSynthesisVoice(identifier: name) { return v }
            if let v = AVSpeechSynthesisVoice(language: name) { return v }
            return AVSpeechSynthesisVoice.speechVoices().first {
                $0.name.lowercased() == name.lowercased()
            }
        }
        return AVSpeechSynthesisVoice(language: config.locale.identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    static func makeUtterance(_ text: String, config: VoiceConfig, voice: AVSpeechSynthesisVoice?) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = config.rate ?? AVSpeechUtteranceDefaultSpeechRate
        return u
    }

    /// Speak through the default output device; blocks until finished.
    @MainActor
    static func speak(_ text: String, config: VoiceConfig) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let voice = await resolveVoice(config: config)
        let utterance = makeUtterance(trimmed, config: config, voice: voice)
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // CLI tools must pump RunLoop.main or AVSpeechSynthesizer never completes.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            var finished = false
            func finish() {
                guard !finished else { return }
                finished = true
                delegate.onFinish = nil
                cont.resume()
            }
            delegate.onFinish = finish
            synthesizer.speak(utterance)

            let rate = max(utterance.rate, 0.01)
            let estSeconds = max(2.0, Double(trimmed.count) / (Double(rate) * 12.0) + 1.5)
            let deadline = Date(timeIntervalSinceNow: min(estSeconds + 5.0, 120.0))

            var sawSpeaking = false
            var idleTicks = 0
            while !finished && Date() < deadline {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
                if synthesizer.isSpeaking {
                    sawSpeaking = true
                    idleTicks = 0
                } else if sawSpeaking {
                    idleTicks += 1
                    if idleTicks >= 3 {
                        finish()
                    }
                }
            }
            finish()
        }

        // Brief tail so the last phonemes reach the output device before process exit.
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    /// Render speech to audio bytes (for server).
    @MainActor
    static func render(_ text: String, config: VoiceConfig) async throws -> (data: Data, contentType: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SpeechOutputError.emptyInput }
        let voice = await resolveVoice(config: config)
        let utterance = makeUtterance(trimmed, config: config, voice: voice)
        final class BufferBox: @unchecked Sendable {
            var finished = false
            var buffers: [AVAudioPCMBuffer] = []
        }
        let box = BufferBox()
        synthesizer.write(utterance) { buffer in
            if let pcm = buffer as? AVAudioPCMBuffer {
                if pcm.frameLength > 0 {
                    box.buffers.append(pcm)
                } else {
                    box.finished = true
                }
            } else {
                box.finished = true
            }
        }
        let deadline = Date(timeIntervalSinceNow: 120)
        while !box.finished && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        guard box.finished else { throw SpeechOutputError.renderFailed }
        guard let first = box.buffers.first else { throw SpeechOutputError.renderFailed }
        let format = first.format
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sayitdev-tts-\(UUID().uuidString).\(config.audioFormat.rawValue)")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        switch config.audioFormat {
        case .wav, .pcm:
            let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            for b in box.buffers { try file.write(from: b) }
            return (try Data(contentsOf: tempURL), config.audioFormat == .wav ? "audio/wav" : "audio/pcm")
        case .aac:
            throw SpeechOutputError.unsupportedFormat("aac")
        }
    }

    static func listVoicesJSON() -> String {
        struct VoiceRow: Encodable {
            let id: String
            let name: String
            let language: String
            let personal: Bool
        }
        let rows = AVSpeechSynthesisVoice.speechVoices().map {
            VoiceRow(
                id: $0.identifier,
                name: $0.name,
                language: $0.language,
                personal: $0.voiceTraits.contains(.isPersonalVoice)
            )
        }
        struct Payload: Encodable { let voices: [VoiceRow] }
        let data = (try? JSONEncoder().encode(Payload(voices: rows))) ?? Data("{}".utf8)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

enum SpeechOutputError: Error, LocalizedError {
    case emptyInput
    case renderFailed
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "TTS input text is empty"
        case .renderFailed: return "Failed to render speech audio"
        case .unsupportedFormat(let f): return "Unsupported audio format: \(f)"
        }
    }
}
