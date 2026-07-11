// ============================================================================
// MicListenPolicyTests.swift — Unit tests for interactive mic listen policy
// ============================================================================

import Foundation
import SayItDevCore

func runMicListenPolicyTests() {
    let cfg = MicListenConfig(
        silenceDuration: 1.5,
        initialSilenceTimeout: 8.0,
        maxDuration: 120.0,
        rmsThreshold: 0.012
    )

    test("initial silence stops after initialSilenceTimeout with no activity") {
        let session = MicListenSession(startedAt: 0)
        try assertNil(session.stopReason(now: 7.9, config: cfg))
        try assertEqual(session.stopReason(now: 8.0, config: cfg), .initialSilence)
    }

    test("ongoing loud audio does not stop early") {
        var session = MicListenSession(startedAt: 0)
        session.noteAudio(now: 1.0, rms: 0.05, threshold: cfg.rmsThreshold)
        session.noteAudio(now: 2.0, rms: 0.04, threshold: cfg.rmsThreshold)
        try assertNil(session.stopReason(now: 2.4, config: cfg))
    }

    test("silence after speech stops once quiet for silenceDuration") {
        var session = MicListenSession(startedAt: 0)
        session.noteAudio(now: 1.0, rms: 0.05, threshold: cfg.rmsThreshold)
        try assertNil(session.stopReason(now: 2.0, config: cfg))
        try assertEqual(session.stopReason(now: 2.5, config: cfg), .silenceAfterSpeech)
    }

    test("partial transcript counts as speech activity") {
        var session = MicListenSession(startedAt: 0)
        session.notePartial(now: 1.0, text: "hello")
        try assertNil(session.stopReason(now: 2.0, config: cfg))
        try assertEqual(session.stopReason(now: 2.5, config: cfg), .silenceAfterSpeech)
    }

    test("maxDuration is a hard cap") {
        var session = MicListenSession(startedAt: 0)
        session.noteAudio(now: 50.0, rms: 0.05, threshold: cfg.rmsThreshold)
        try assertEqual(session.stopReason(now: 120.0, config: cfg), .maxDuration)
    }

    test("rmsLevel computes root-mean-square") {
        try assertEqual(MicListenPolicy.rmsLevel(samples: [0.0, 0.0]), 0.0)
        try assertEqual(MicListenPolicy.rmsLevel(samples: [1.0, -1.0]), 1.0)
        try assertEqual(MicListenPolicy.rmsLevel(samples: [0.3, 0.4]), 0.35355338, accuracy: 0.0001)
    }

    test("LiveTranscriptLine overwrites the current terminal row") {
        try assertEqual(LiveTranscriptLine.overwrite("hi"), "\r\u{001B}[Khi")
    }
}

private func assertEqual<T: FloatingPoint>(
    _ a: T,
    _ b: T,
    accuracy: T,
    _ msg: String = ""
) throws {
    guard abs(a - b) <= accuracy else {
        throw TestFailure("\(a) != \(b) ± \(accuracy)\(msg.isEmpty ? "" : " — \(msg)")")
    }
}
