// ============================================================================
// SpeechInput.swift — On-device STT (SpeechAnalyzer when available, SFSpeechRecognizer fallback)
// ============================================================================

@preconcurrency import Speech
import AVFAudio
import AVFoundation
import Foundation
import SayItDevCLI
import SayItDevCore
import os

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
    private static let permissionMessage =
        "Speech recognition permission denied. Enable in System Settings → Privacy → Speech Recognition."

    // Public entry points hop to MainActor once and stay there for the whole operation.
    // Hummingbird handlers run on NIO worker threads; Speech/TCC abort off the main thread.

    static func requestSpeechPermission() async throws {
        try await onMainActor { try await ensureSpeechAuthorized() }
    }

    static func requestPermissions() async throws {
        try await onMainActor {
            try await ensureSpeechAuthorized()
            try await ensureMicAuthorized()
        }
    }

    static func transcribeFile(url: URL, config: VoiceConfig) async throws -> TranscriptionResult {
        try await onMainActor {
            try await ensureSpeechAuthorized()
            do {
                return try await transcribeFileLegacy(url: url, config: config)
            } catch {
                if #available(macOS 26.0, *) {
                    return try await transcribeFileModern(url: url, config: config)
                }
                throw error
            }
        }
    }

    static func transcribeMic(
        config: VoiceConfig,
        listenConfig: MicListenConfig = .interactive,
        onPartial: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        try await onMainActor {
            try await ensureSpeechAuthorized()
            try await ensureMicAuthorized()
            return try await transcribeMicLegacy(
                config: config,
                listenConfig: listenConfig,
                onPartial: onPartial
            )
        }
    }

    /// Warm speech frameworks when already authorized. Skips prompting at startup
    /// so headless test runners and CI subprocesses do not abort on TCC dialogs.
    static func prewarmForServer() async {
        try? await onMainActor {
            guard SFSpeechRecognizer.authorizationStatus() == .authorized else { return }
            _ = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
    }

    @MainActor
    private static func onMainActor<T: Sendable>(
        _ body: @MainActor () async throws -> T
    ) async throws -> T {
        try await body()
    }

    @MainActor
    private static func ensureSpeechAuthorized() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return
        case .denied, .restricted:
            throw SpeechInputError.permissionDenied(permissionMessage)
        case .notDetermined:
            let ok = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
            guard ok else {
                throw SpeechInputError.permissionDenied(permissionMessage)
            }
        @unknown default:
            throw SpeechInputError.permissionDenied(permissionMessage)
        }
    }

    @MainActor
    private static func ensureMicAuthorized() async throws {
        let ok = await AVAudioApplication.requestRecordPermission()
        guard ok else {
            throw SpeechInputError.permissionDenied(
                "Microphone permission denied. Enable in System Settings → Privacy → Microphone."
            )
        }
    }

    @MainActor
    private static func ensureInputDeviceAvailable(config: VoiceConfig) throws {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        let devices = discovery.devices
        guard !devices.isEmpty else {
            throw SpeechInputError.noInputDevice
        }
        if let uid = config.inputDeviceUID, !uid.isEmpty {
            guard devices.contains(where: { $0.uniqueID == uid }) else {
                throw SpeechInputError.transcriptionFailed("No input device with UID: \(uid)")
            }
        }
    }

    @available(macOS 26.0, *)
    @MainActor
    private static func transcribeFileModern(url: URL, config: VoiceConfig) async throws -> TranscriptionResult {
        let attrs: Set<SpeechTranscriber.ResultAttributeOption> = config.timestamps ? [.audioTimeRange] : []
        let transcriber = SpeechTranscriber(
            locale: config.locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: attrs
        )
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            do {
                try await request.downloadAndInstall()
            } catch {
                throw SpeechInputError.assetInstallFailed
            }
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

    @MainActor
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

    @MainActor
    private static func transcribeMicLegacy(
        config: VoiceConfig,
        listenConfig: MicListenConfig,
        onPartial: (@Sendable (String) -> Void)?
    ) async throws -> String {
        try ensureInputDeviceAvailable(config: config)
        guard let recognizer = SFSpeechRecognizer(locale: config.locale), recognizer.isAvailable else {
            throw SpeechInputError.transcriptionFailed("Speech recognizer unavailable")
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let bridge = MicCaptureBridge(
            startedAt: Date.timeIntervalSinceReferenceDate,
            listenConfig: listenConfig,
            request: request
        )
        bridge.installTap(on: input, format: format)
        engine.prepare()
        try engine.start()

        defer {
            if !bridge.captureStopped {
                input.removeTap(onBus: 0)
                engine.stop()
                request.endAudio()
            }
        }

        return try await withCheckedThrowingContinuation { cont in
            final class State: @unchecked Sendable {
                var resumed = false
                var task: SFSpeechRecognitionTask?
            }
            let state = State()

            func resumeOnce(with result: Result<String, Error>) {
                guard !state.resumed else { return }
                state.resumed = true
                switch result {
                case .success(let text):
                    cont.resume(returning: text)
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }

            func finalize(with text: String) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    resumeOnce(with: .failure(SpeechInputError.emptyAudio))
                } else {
                    resumeOnce(with: .success(trimmed))
                }
            }

            func stopCapture() {
                guard !bridge.captureStopped else { return }
                bridge.markCaptureStopped()
                input.removeTap(onBus: 0)
                engine.stop()
                request.endAudio()
                state.task?.finish()
            }

            state.task = recognizer.recognitionTask(with: request) { result, error in
                if state.resumed { return }
                if let error {
                    let ns = error as NSError
                    if ns.domain == "kAFAssistantErrorDomain", ns.code == 216, !bridge.lastPartial.isEmpty {
                        finalize(with: bridge.lastPartial)
                        return
                    }
                    resumeOnce(with: .failure(SpeechInputError.transcriptionFailed(error.localizedDescription)))
                    return
                }
                guard let result else { return }
                let text = result.bestTranscription.formattedString
                bridge.notePartial(text)
                onPartial?(text)
                if result.isFinal {
                    finalize(with: text)
                }
            }

            Task { @MainActor in
                while !state.resumed {
                    try? await Task.sleep(for: .milliseconds(100))
                    if state.resumed { break }
                    if let reason = bridge.pollStopReason() {
                        bridge.markShouldStop(reason: reason)
                    }
                    if bridge.shouldStop {
                        stopCapture()
                        try? await Task.sleep(for: .milliseconds(800))
                        if !state.resumed {
                            finalize(with: bridge.lastPartial)
                        }
                        break
                    }
                }
            }
        }
    }
}
