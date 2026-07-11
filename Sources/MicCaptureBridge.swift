// ============================================================================
// MicCaptureBridge.swift — Realtime-safe mic tap + silence monitor for STT
// AVAudioEngine tap callbacks run on a realtime queue; they must not touch
// MainActor state (Swift 6 traps with SIGTRAP otherwise).
// ============================================================================

@preconcurrency import Speech
import AVFAudio
import AVFoundation
import Foundation
import SayItDevCore
import os

private func voiceDebug(_ message: String) {
    guard ProcessInfo.processInfo.environment["DEV_VOICE_DEBUG"] == "1" else { return }
    if let data = "voice: \(message)\n".data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

final class MicCaptureBridge: @unchecked Sendable {
    private let request: SFSpeechAudioBufferRecognitionRequest
    private let listenConfig: MicListenConfig
    private let sessionLock: OSAllocatedUnfairLock<MicListenSession>
    private let flagsLock: OSAllocatedUnfairLock<Flags>

    struct Flags: Sendable {
        var shouldStop = false
        var stopReason: MicListenStopReason?
        var lastPartial = ""
        var audioBufferCount = 0
    }

    private let stopLatch = TeardownLatch()
    private let acceptsAudio = OSAllocatedUnfairLock(initialState: true)

    init(startedAt: TimeInterval, listenConfig: MicListenConfig, request: SFSpeechAudioBufferRecognitionRequest) {
        self.request = request
        self.listenConfig = listenConfig
        self.sessionLock = OSAllocatedUnfairLock(initialState: MicListenSession(startedAt: startedAt))
        self.flagsLock = OSAllocatedUnfairLock(initialState: Flags())
    }

    nonisolated func installTap(on input: AVAudioInputNode, format: AVAudioFormat) {
        let request = self.request
        let listenConfig = self.listenConfig
        let sessionLock = self.sessionLock
        let flagsLock = self.flagsLock
        let acceptsAudio = self.acceptsAudio
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            // Hold `acceptsAudio` across the append so it cannot interleave with
            // `endAudio()` on the main thread. Appending after endAudio corrupts
            // the recognition request's heap ("freed pointer was not the last
            // allocation"), so the append and the endAudio must be mutually
            // exclusive under the same lock.
            let appended = acceptsAudio.withLock { accepting -> Bool in
                guard accepting else { return false }
                if buffer.frameLength > 0 {
                    flagsLock.withLock { $0.audioBufferCount += 1 }
                }
                request.append(buffer)
                return true
            }
            guard appended else { return }
            let rms = MicCaptureBridge.rmsLevel(from: buffer)
            let now = Date.timeIntervalSinceReferenceDate
            sessionLock.withLock { session in
                session.noteAudio(now: now, rms: rms, threshold: listenConfig.rmsThreshold)
                if let reason = session.stopReason(now: now, config: listenConfig) {
                    flagsLock.withLock { flags in
                        flags.shouldStop = true
                        flags.stopReason = reason
                    }
                }
            }
        }
    }

    func notePartial(_ text: String) {
        flagsLock.withLock { $0.lastPartial = text }
        let now = Date.timeIntervalSinceReferenceDate
        sessionLock.withLock { session in
            session.notePartial(now: now, text: text)
            if let reason = session.stopReason(now: now, config: listenConfig) {
                flagsLock.withLock { flags in
                    flags.shouldStop = true
                    flags.stopReason = reason
                }
            }
        }
    }

    func pollStopReason(now: TimeInterval = Date.timeIntervalSinceReferenceDate) -> MicListenStopReason? {
        sessionLock.withLock { $0.stopReason(now: now, config: listenConfig) }
    }

    var shouldStop: Bool {
        flagsLock.withLock { $0.shouldStop }
    }

    var stopReason: MicListenStopReason? {
        flagsLock.withLock { $0.stopReason }
    }

    var lastPartial: String {
        flagsLock.withLock { $0.lastPartial }
    }

    var hasReceivedAudio: Bool {
        flagsLock.withLock { $0.audioBufferCount > 0 }
    }

    /// Returns `true` exactly once when this caller should tear down the mic graph.
    func claimStop() -> Bool {
        stopLatch.claim()
    }

    func stopAcceptingAudio() {
        acceptsAudio.withLock { $0 = false }
    }

    /// End the recognition request once, only after the tap has stopped appending.
    func endAudioOnce() {
        acceptsAudio.withLock { accepting in
            guard !accepting else { return }
            request.endAudio()
        }
    }

    /// Realtime-safe; callable from the audio or speech recognition callback queue.
    nonisolated func stopAcceptingAudioFromCallback() {
        acceptsAudio.withLock { $0 = false }
    }

    func markShouldStop(reason: MicListenStopReason) {
        flagsLock.withLock { flags in
            flags.shouldStop = true
            flags.stopReason = reason
        }
    }

    nonisolated static func rmsLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count {
            let sample = channelData[i]
            sum += sample * sample
        }
        return sqrt(sum / Float(count))
    }
}

// MARK: - MainActor session owner

/// Owns the mic graph and performs idempotent teardown on MainActor before any caller resumes.
@MainActor
final class MicCaptureSession {
    let engine = AVAudioEngine()
    let request: SFSpeechAudioBufferRecognitionRequest
    let recognizer: SFSpeechRecognizer
    let bridge: MicCaptureBridge
    var recognitionTask: SFSpeechRecognitionTask?
    /// Set when the recognizer delivered `.isFinal` (skip redundant `endAudio`).
    var endedNaturally = false
    private(set) var startedAt: TimeInterval = 0

    private var input: AVAudioInputNode { engine.inputNode }

    init(locale: Locale, listenConfig: MicListenConfig) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechInputError.transcriptionFailed("Speech recognizer unavailable")
        }
        self.recognizer = recognizer
        request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        bridge = MicCaptureBridge(
            startedAt: Date.timeIntervalSinceReferenceDate,
            listenConfig: listenConfig,
            request: request
        )
    }

    func start() throws {
        // Wait briefly for the input to report a usable format before installing
        // the tap. A fresh engine after teardown, or a Bluetooth input mid
        // A2DP->HFP profile switch, can momentarily report a 0-channel/0-Hz
        // format; installing a tap with that traps. When the format is already
        // valid (the normal first-capture case) this loop does not run, so there
        // is zero added latency on the working path. Never hard-fails on a slow
        // warmup - the 8s initial-silence path handles a genuinely quiet mic.
        var format = input.outputFormat(forBus: 0)
        var waited = 0
        while !MicListenPolicy.isValidCaptureFormat(
            channelCount: format.channelCount,
            sampleRate: format.sampleRate
        ) && waited < 40 {
            Thread.sleep(forTimeInterval: 0.05)
            waited += 1
            format = input.outputFormat(forBus: 0)
        }
        guard MicListenPolicy.isValidCaptureFormat(
            channelCount: format.channelCount,
            sampleRate: format.sampleRate
        ) else {
            voiceDebug("no valid input format after \(waited * 50)ms ch=\(format.channelCount) sr=\(format.sampleRate)")
            throw SpeechInputError.noInputDevice
        }
        bridge.installTap(on: input, format: format)
        engine.prepare()
        try engine.start()
        startedAt = Date.timeIntervalSinceReferenceDate
        voiceDebug("engine started ch=\(format.channelCount) sr=\(format.sampleRate) running=\(engine.isRunning) waited=\(waited * 50)ms")
    }

    /// Idempotent mic graph teardown. Call on MainActor before resuming any async continuation.
    func stop(endAudio: Bool) {
        guard bridge.claimStop() else { return }
        bridge.stopAcceptingAudio()
        input.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
        if endAudio, !endedNaturally {
            bridge.endAudioOnce()
        }
        // Never cancel the recognition task — cancel during an in-flight Speech
        // callback corrupts the framework heap ("freed pointer was not the last
        // allocation"). The task completes naturally after endAudio / isFinal.
        voiceDebug("engine stopped")
    }

    /// Synchronous settle so CoreAudio releases the input before the next capture.
    func finishTeardown() {
        recognitionTask = nil
        Thread.sleep(forTimeInterval: 0.25)
        voiceDebug("teardown complete")
    }

    var lastPartial: String { bridge.lastPartial }
    var shouldStop: Bool { bridge.shouldStop }
    var stopReason: MicListenStopReason? { bridge.stopReason }
    var hasReceivedAudio: Bool { bridge.hasReceivedAudio }

    func notePartial(_ text: String) {
        bridge.notePartial(text)
    }

    func pollStopReason() -> MicListenStopReason? {
        bridge.pollStopReason()
    }

    func markShouldStop(reason: MicListenStopReason) {
        bridge.markShouldStop(reason: reason)
    }
}
