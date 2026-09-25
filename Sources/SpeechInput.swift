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
    case microphoneNoAudio
    case transcriptionFailed(String)
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let m): return m
        case .assetInstallFailed: return "Failed to install speech recognition model assets"
        case .noInputDevice: return "No microphone input device available"
        case .microphoneNoAudio:
            return "Microphone opened but received no audio — wait a moment and try again (another capture may still be releasing the device)"
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

        let session = try MicCaptureSession(locale: config.locale, listenConfig: listenConfig)
        try session.start()

        final class CaptureState: @unchecked Sendable {
            var resumed = false
            var result: Result<String, Error>?
        }
        let state = CaptureState()

        @MainActor
        func finishCapture(with result: Result<String, Error>) {
            guard !state.resumed else { return }
            state.resumed = true
            session.finishTeardown()
            state.result = result
        }

        @MainActor
        func finalize(with text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                finishCapture(with: .failure(SpeechInputError.emptyAudio))
            } else {
                finishCapture(with: .success(trimmed))
            }
        }

        @MainActor
        func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
            guard !state.resumed else { return }
            if let error {
                let ns = error as NSError
                if ns.domain == "kAFAssistantErrorDomain", ns.code == 216 {
                    session.endedNaturally = true
                    session.stop(endAudio: false)
                    finalize(with: session.lastPartial)
                    return
                }
                session.endedNaturally = true
                session.stop(endAudio: true)
                finishCapture(with: .failure(SpeechInputError.transcriptionFailed(error.localizedDescription)))
                return
            }
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            session.notePartial(text)
            onPartial?(text)
            if result.isFinal {
                session.endedNaturally = true
                session.stop(endAudio: false)
                finalize(with: text)
            }
        }

        let captureBridge = session.bridge
        session.recognitionTask = session.recognizer.recognitionTask(with: session.request) { result, error in
            let isTerminal = error != nil || result?.isFinal == true
            if isTerminal {
                captureBridge.stopAcceptingAudioFromCallback()
            }
            Task { @MainActor in
                handleRecognition(result: result, error: error)
            }
        }

        // Poll silence in this same @MainActor async function (no nested monitor Task).
        while !state.resumed {
            try await Task.sleep(for: .milliseconds(100))
            if state.resumed { break }

            if let reason = session.pollStopReason() {
                session.markShouldStop(reason: reason)
            }
            if session.shouldStop {
                let heardSpeech = session.stopReason != .initialSilence
                    || !session.lastPartial.isEmpty
                session.stop(endAudio: heardSpeech)
                if heardSpeech {
                    for _ in 0..<8 where !state.resumed {
                        try await Task.sleep(for: .milliseconds(100))
                    }
                }
                if !state.resumed {
                    finalize(with: session.lastPartial)
                }
                break
            }
        }

        switch state.result! {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }
}
