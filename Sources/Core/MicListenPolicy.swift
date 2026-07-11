// ============================================================================
// MicListenPolicy.swift — Silence/end detection for interactive mic STT
// Pure Swift, testable without AVFoundation.
// ============================================================================

import Foundation

/// Tunables for `dev --listen` / agent mic capture.
public struct MicListenConfig: Sendable, Equatable {
    /// Stop after this much quiet time once speech or partial text was seen.
    public var silenceDuration: TimeInterval
    /// Stop with no transcript when no speech is detected within this window.
    public var initialSilenceTimeout: TimeInterval
    /// Hard safety cap (seconds).
    public var maxDuration: TimeInterval
    /// RMS level at or above which audio counts as speech.
    public var rmsThreshold: Float

    public init(
        silenceDuration: TimeInterval = 1.5,
        initialSilenceTimeout: TimeInterval = 8.0,
        maxDuration: TimeInterval = 120.0,
        rmsThreshold: Float = 0.012
    ) {
        self.silenceDuration = silenceDuration
        self.initialSilenceTimeout = initialSilenceTimeout
        self.maxDuration = maxDuration
        self.rmsThreshold = rmsThreshold
    }

    public static let interactive = MicListenConfig()
}

public enum MicListenStopReason: Sendable, Equatable {
    case silenceAfterSpeech
    case initialSilence
    case maxDuration
}

/// Tracks mic activity and decides when interactive listen should finalize.
public struct MicListenSession: Sendable, Equatable {
    public var startedAt: TimeInterval
    public var lastLoudAt: TimeInterval?
    public var lastPartialAt: TimeInterval?
    public var hasNonEmptyPartial: Bool

    public init(startedAt: TimeInterval) {
        self.startedAt = startedAt
        self.lastLoudAt = nil
        self.lastPartialAt = nil
        self.hasNonEmptyPartial = false
    }

    public mutating func noteAudio(now: TimeInterval, rms: Float, threshold: Float) {
        if rms >= threshold {
            lastLoudAt = now
        }
    }

    public mutating func notePartial(now: TimeInterval, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hasNonEmptyPartial = true
        lastPartialAt = now
    }

    public func stopReason(now: TimeInterval, config: MicListenConfig) -> MicListenStopReason? {
        let elapsed = now - startedAt
        if elapsed >= config.maxDuration {
            return .maxDuration
        }

        let heardAnything = hasNonEmptyPartial || lastLoudAt != nil
        if !heardAnything {
            return elapsed >= config.initialSilenceTimeout ? .initialSilence : nil
        }

        let lastActivity = max(lastLoudAt ?? startedAt, lastPartialAt ?? startedAt)
        if now - lastActivity >= config.silenceDuration {
            return .silenceAfterSpeech
        }
        return nil
    }
}

public enum MicListenPolicy {
    public static func rmsLevel(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        return sqrt(sum / Float(samples.count))
    }
}

/// Terminal helpers for in-place partial transcript rendering on stdout.
public enum LiveTranscriptLine {
    public static func overwrite(_ text: String) -> String {
        "\r\u{001B}[K\(text)"
    }
}
