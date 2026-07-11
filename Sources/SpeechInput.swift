// ============================================================================
// SpeechInput.swift — On-device STT (SpeechAnalyzer when available, SFSpeechRecognizer fallback)
// ============================================================================

@preconcurrency import Speech
import AVFAudio
import Foundation
import SayItDevCLI

struct TranscriptionSegment: Sendable, Equatable {
    var text: String
    var start: TimeInterval
    var end: TimeInterval
}

struct TranscriptionResult: Sendable, Equatable {
    var text: String
    var segments: [TranscriptionSegment]?
}

enum SpeechInputError: Error, LocalizedError {
    case permissionDenied(String)
    case assetInstallFailed
    case noInputDevice
    case transcriptionFailed(String)
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let m): return m
        case .assetInstallFailed: return "Failed to install speech recognition model assets"
        case .noInputDevice: return "No microphone input device available"
        case .transcriptionFailed(let m): return m
        case .emptyAudio: return "No speech detected in audio"
        }
    }
}

enum SpeechInput {
    static func requestPermissions() async throws {
        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechOK else {
            throw SpeechInputError.permissionDenied(
                "Speech recognition permission denied. Enable in System Settings → Privacy → Speech Recognition."
            )
        }
        let micOK = await AVAudioApplication.requestRecordPermission()
        guard micOK else {
            throw SpeechInputError.permissionDenied(
                "Microphone permission denied. Enable in System Settings → Privacy → Microphone."
            )
        }
    }

    static func transcribeFile(url: URL, config: VoiceConfig) async throws -> TranscriptionResult {
        try await requestPermissions()
        if #available(macOS 26.0, *) {
            do {
                return try await transcribeFileModern(url: url, config: config)
            } catch {
                return try await transcribeFileLegacy(url: url, config: config)
            }
        }
        return try await transcribeFileLegacy(url: url, config: config)
    }

    @available(macOS 26.0, *)
    private static func transcribeFileModern(url: URL, config: VoiceConfig) async throws -> TranscriptionResult {
        let attrs: Set<SpeechTranscriber.ResultAttributeOption> = config.timestamps ? [.audioTimeRange] : []
        let transcriber = SpeechTranscriber(
            locale: config.locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: attrs
        )
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        final class Box: @unchecked Sendable {
            var text = ""
            var segments: [TranscriptionSegment] = []
        }
        let box = Box()
        let collector = Task {
            for try await result in transcriber.results where result.isFinal {
                let slice = String(result.text.characters)
                if slice.isEmpty { continue }
                box.text += slice
                if config.timestamps, let range = result.text.runs.first?.audioTimeRange {
                    box.segments.append(TranscriptionSegment(
                        text: slice,
                        start: range.start.seconds,
                        end: range.end.seconds
                    ))
                }
            }
        }
        let file = try AVAudioFile(forReading: url)
        _ = try await analyzer.analyzeSequence(from: file)
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        _ = await collector.result
        let trimmed = box.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SpeechInputError.emptyAudio }
        return TranscriptionResult(text: trimmed, segments: box.segments.isEmpty ? nil : box.segments)
    }

    private static func transcribeFileLegacy(url: URL, config: VoiceConfig) async throws -> TranscriptionResult {
        guard let recognizer = SFSpeechRecognizer(locale: config.locale), recognizer.isAvailable else {
            throw SpeechInputError.transcriptionFailed("Speech recognizer unavailable for \(config.locale.identifier)")
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        return try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    cont.resume(throwing: SpeechInputError.transcriptionFailed(error.localizedDescription))
                    return
                }
                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    cont.resume(throwing: SpeechInputError.emptyAudio)
                } else {
                    cont.resume(returning: TranscriptionResult(text: text, segments: nil))
                }
            }
        }
    }

    static func transcribeMic(config: VoiceConfig, maxDuration: TimeInterval = 45) async throws -> String {
        try await requestPermissions()
        return try await transcribeMicLegacy(config: config, maxDuration: maxDuration)
    }

    private static func transcribeMicLegacy(config: VoiceConfig, maxDuration: TimeInterval) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: config.locale), recognizer.isAvailable else {
            throw SpeechInputError.transcriptionFailed("Speech recognizer unavailable")
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try engine.start()

        defer {
            input.removeTap(onBus: 0)
            engine.stop()
            request.endAudio()
        }

        return try await withCheckedThrowingContinuation { cont in
            final class State: @unchecked Sendable {
                var finished = false
                var task: SFSpeechRecognitionTask?
            }
            let state = State()
            state.task = recognizer.recognitionTask(with: request) { result, error in
                if state.finished { return }
                if let error {
                    state.finished = true
                    cont.resume(throwing: SpeechInputError.transcriptionFailed(error.localizedDescription))
                    return
                }
                guard let result, result.isFinal else { return }
                state.finished = true
                let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    cont.resume(throwing: SpeechInputError.emptyAudio)
                } else {
                    cont.resume(returning: text)
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + maxDuration) {
                if state.finished { return }
                state.finished = true
                state.task?.cancel()
                cont.resume(throwing: SpeechInputError.transcriptionFailed("Listening timed out"))
            }
        }
    }
}
