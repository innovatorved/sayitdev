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

final class MicCaptureBridge: @unchecked Sendable {
    private let request: SFSpeechAudioBufferRecognitionRequest
    private let listenConfig: MicListenConfig
    private let sessionLock: OSAllocatedUnfairLock<MicListenSession>
    private let flagsLock: OSAllocatedUnfairLock<Flags>

    struct Flags: Sendable {
        var shouldStop = false
        var stopReason: MicListenStopReason?
        var captureStopped = false
        var lastPartial = ""
    }

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
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            request.append(buffer)
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

    var lastPartial: String {
        flagsLock.withLock { $0.lastPartial }
    }

    var captureStopped: Bool {
        flagsLock.withLock { $0.captureStopped }
    }

    func markCaptureStopped() {
        flagsLock.withLock { $0.captureStopped = true }
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
