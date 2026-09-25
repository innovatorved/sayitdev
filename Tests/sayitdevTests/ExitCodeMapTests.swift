// ============================================================================
// ExitCodeMapTests.swift — Lockdown for SayItDevError -> CLI exit-code mapping.
//
// Exit codes are a stable CLI contract (documented in the man page). Every
// `SayItDevError` case must map to the correct exit code, and changing that
// mapping must be a deliberate, visible diff.
// ============================================================================

import Foundation
import SayItDevCore
import SayItDevCLI

func runExitCodeMapTests() {
    test("SayItDevExitCodes: guardrailViolation -> exitGuardrail (3)") {
        try assertEqual(SayItDevExitCodes.code(for: .guardrailViolation), 3)
    }
    test("SayItDevExitCodes: refusal -> exitGuardrail (3) — same as guardrail for script compat") {
        try assertEqual(SayItDevExitCodes.code(for: .refusal("any explanation")), 3)
    }
    test("SayItDevExitCodes: refusal exit code is independent of associated text") {
        try assertEqual(SayItDevExitCodes.code(for: .refusal("")), 3)
        try assertEqual(SayItDevExitCodes.code(for: .refusal("short")), 3)
        try assertEqual(SayItDevExitCodes.code(for: .refusal(String(repeating: "x", count: 10_000))), 3)
    }
    test("SayItDevExitCodes: contextOverflow -> 4") {
        try assertEqual(SayItDevExitCodes.code(for: .contextOverflow), 4)
    }
    test("SayItDevExitCodes: rateLimited and concurrentRequest -> 6") {
        try assertEqual(SayItDevExitCodes.code(for: .rateLimited), 6)
        try assertEqual(SayItDevExitCodes.code(for: .concurrentRequest), 6)
    }
    test("SayItDevExitCodes: assetsUnavailable -> runtime error (1), not modelUnavailable") {
        // Rationale: exitModelUnavailable (5) is for the availability *precheck*
        // (Apple Intelligence disabled, device ineligible). assetsUnavailable is a
        // transient loading state that the model itself surfaces during inference.
        try assertEqual(SayItDevExitCodes.code(for: .assetsUnavailable), 1)
    }
    test("SayItDevExitCodes: all remaining cases -> runtime error (1)") {
        try assertEqual(SayItDevExitCodes.code(for: .unsupportedGuide), 1)
        try assertEqual(SayItDevExitCodes.code(for: .decodingFailure("x")), 1)
        try assertEqual(SayItDevExitCodes.code(for: .unsupportedLanguage("x")), 1)
        try assertEqual(SayItDevExitCodes.code(for: .toolExecution("x")), 1)
        try assertEqual(SayItDevExitCodes.code(for: .unknown("x")), 1)
    }
    test("SayItDevExitCodes: constants match documented values") {
        try assertEqual(SayItDevExitCodes.success, 0)
        try assertEqual(SayItDevExitCodes.runtimeError, 1)
        try assertEqual(SayItDevExitCodes.usageError, 2)
        try assertEqual(SayItDevExitCodes.guardrail, 3)
        try assertEqual(SayItDevExitCodes.contextOverflow, 4)
        try assertEqual(SayItDevExitCodes.modelUnavailable, 5)
        try assertEqual(SayItDevExitCodes.rateLimited, 6)
        try assertEqual(SayItDevExitCodes.noCode, 7)
    }
}
