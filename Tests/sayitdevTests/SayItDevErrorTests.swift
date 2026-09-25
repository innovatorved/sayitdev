import Foundation
import SayItDevCore

func runSayItDevErrorTests() {
    test("guardrail keyword → .guardrailViolation") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "guardrail violation occurred"])
        try assertEqual(SayItDevError.classify(err), .guardrailViolation)
    }
    test("content policy keyword → .guardrailViolation") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "content policy blocked this request"])
        try assertEqual(SayItDevError.classify(err), .guardrailViolation)
    }
    test("context window keyword → .contextOverflow") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "exceeded context window size"])
        try assertEqual(SayItDevError.classify(err), .contextOverflow)
    }
    test("rate limit keyword → .rateLimited") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "rate limited, try later"])
        try assertEqual(SayItDevError.classify(err), .rateLimited)
    }
    test("concurrent keyword → .concurrentRequest") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "concurrent requests not allowed"])
        try assertEqual(SayItDevError.classify(err), .concurrentRequest)
    }
    test("unknown error → .unknown") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "something went wrong"])
        if case .unknown = SayItDevError.classify(err) { } else {
            throw TestFailure("expected .unknown")
        }
    }
    test("MCP server errors map to toolExecution") {
        let err = MCPError.serverError("Tool 'divide' failed: division by zero")
        try assertEqual(
            SayItDevError.classify(err),
            .toolExecution("Tool 'divide' failed: division by zero")
        )
    }
    test("MCP timeouts map to toolExecution") {
        let err = MCPError.timedOut("Tool 'multiply' timed out after 5s")
        try assertEqual(
            SayItDevError.classify(err),
            .toolExecution("Tool 'multiply' timed out after 5s")
        )
    }
    test("CLI labels") {
        try assertEqual(SayItDevError.guardrailViolation.cliLabel, "[guardrail]")
        try assertEqual(SayItDevError.contextOverflow.cliLabel, "[context overflow]")
        try assertEqual(SayItDevError.rateLimited.cliLabel, "[rate limited]")
        try assertEqual(SayItDevError.concurrentRequest.cliLabel, "[busy]")
        try assertEqual(SayItDevError.toolExecution("x").cliLabel, "[tool error]")
        try assertEqual(SayItDevError.unknown("x").cliLabel, "[error]")
    }
    test("OpenAI error types") {
        try assertEqual(SayItDevError.guardrailViolation.openAIType, "content_policy_violation")
        try assertEqual(SayItDevError.contextOverflow.openAIType, "context_length_exceeded")
        try assertEqual(SayItDevError.rateLimited.openAIType, "rate_limit_error")
        try assertEqual(SayItDevError.concurrentRequest.openAIType, "rate_limit_error")
        try assertEqual(SayItDevError.toolExecution("x").openAIType, "server_error")
    }
    test("HTTP status codes") {
        try assertEqual(SayItDevError.guardrailViolation.httpStatusCode, 400)
        try assertEqual(SayItDevError.contextOverflow.httpStatusCode, 400)
        try assertEqual(SayItDevError.rateLimited.httpStatusCode, 429)
        try assertEqual(SayItDevError.concurrentRequest.httpStatusCode, 429)
        try assertEqual(SayItDevError.toolExecution("x").httpStatusCode, 500)
        try assertEqual(SayItDevError.unknown("x").httpStatusCode, 500)
    }
    test("classify passes through existing SayItDevError unchanged") {
        try assertEqual(SayItDevError.classify(SayItDevError.contextOverflow), .contextOverflow)
        try assertEqual(SayItDevError.classify(SayItDevError.guardrailViolation), .guardrailViolation)
        try assertEqual(SayItDevError.classify(SayItDevError.rateLimited), .rateLimited)
        try assertEqual(SayItDevError.classify(SayItDevError.concurrentRequest), .concurrentRequest)
        try assertEqual(SayItDevError.classify(SayItDevError.assetsUnavailable), .assetsUnavailable)
        try assertEqual(SayItDevError.classify(SayItDevError.refusal("r")), .refusal("r"))
        try assertEqual(SayItDevError.classify(SayItDevError.toolExecution("x")), .toolExecution("x"))
    }
    test("classify maps every known FoundationModels GenerationError case") {
        let localized = "localized details"
        let cases: [(caseName: String, expected: SayItDevError)] = [
            ("exceededContextWindowSize", .contextOverflow),
            ("assetsUnavailable", .assetsUnavailable),
            ("guardrailViolation", .guardrailViolation),
            ("unsupportedGuide", .unsupportedGuide),
            ("unsupportedLanguageOrLocale", .unsupportedLanguage(localized)),
            ("decodingFailure", .decodingFailure(localized)),
            ("rateLimited", .rateLimited),
            ("concurrentRequests", .concurrentRequest),
            ("refusal", .refusal(localized)),
        ]

        for item in cases {
            let err = FoundationModelsGenerationErrorStub(caseName: item.caseName, localizedMsg: localized)
            try assertEqual(SayItDevError.classify(err), item.expected, "case=\(item.caseName)")
        }
    }
    test("classify preserves refusal explanation text, distinct from guardrailViolation") {
        let refusal = FoundationModelsGenerationErrorStub(
            caseName: "refusal",
            localizedMsg: "I cannot provide that information."
        )
        let classified = SayItDevError.classify(refusal)
        if case .refusal(let text) = classified {
            try assertEqual(text, "I cannot provide that information.")
        } else {
            throw TestFailure("expected .refusal, got \(classified)")
        }
        // And guardrailViolation stays distinct
        let guardrail = FoundationModelsGenerationErrorStub(
            caseName: "guardrailViolation",
            localizedMsg: "Blocked by safety policy"
        )
        try assertEqual(SayItDevError.classify(guardrail), .guardrailViolation)
    }
    test("classify string fallback detects refusal keywords") {
        for keyword in ["refused", "refusal", "declined"] {
            let err = NSError(domain: "FM", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "The model \(keyword) to respond"])
            if case .refusal = SayItDevError.classify(err) {
                continue
            }
            throw TestFailure("expected .refusal for keyword '\(keyword)'")
        }
    }
    test("classify passthrough for refusal") {
        let original = SayItDevError.refusal("preserve me")
        try assertEqual(SayItDevError.classify(original), .refusal("preserve me"))
    }
    test("refusal error properties") {
        // Per OpenAI wire format, an output-side refusal is a successful
        // completion (HTTP 200) with finish_reason=content_filter and the
        // refusal text populated on the assistant message. CLI semantics
        // remain separate: the CLI still exits with the guardrail code (3).
        let err = SayItDevError.refusal("Model says no")
        try assertEqual(err.cliLabel, "[refusal]")
        try assertEqual(err.openAIType, "content_policy_violation")
        try assertEqual(err.httpStatusCode, 200)
        try assertTrue(err.openAIMessage.contains("Model says no"))
        try assertTrue(!err.isRetryable)
    }
    test("refusal Equatable: same text equal, different text unequal, distinct from guardrailViolation") {
        try assertEqual(SayItDevError.refusal("a"), SayItDevError.refusal("a"))
        try assertTrue(SayItDevError.refusal("a") != SayItDevError.refusal("b"))
        try assertTrue(SayItDevError.refusal("") != SayItDevError.guardrailViolation)
        try assertTrue(SayItDevError.refusal("text") != SayItDevError.unknown("text"))
    }
    test("refusal Hashable: round-trips through Set with associated text") {
        let set: Set<SayItDevError> = [
            .refusal("one"),
            .refusal("two"),
            .refusal("one"),            // dupe of the first
            .guardrailViolation,
        ]
        try assertEqual(set.count, 3, "duplicate refusal('one') must collapse, guardrailViolation stays distinct")
        try assertTrue(set.contains(.refusal("one")))
        try assertTrue(set.contains(.refusal("two")))
        try assertTrue(set.contains(.guardrailViolation))
        try assertTrue(!set.contains(.refusal("three")))
    }
    test("refusal debugDescription is a stable, reflective format") {
        try assertEqual(
            SayItDevError.refusal("I cannot help with that.").debugDescription,
            #"SayItDevError.refusal("I cannot help with that.")"#
        )
        // Internal quotes in the explanation must be escaped by String(reflecting:).
        try assertEqual(
            SayItDevError.refusal(#"he said "no""#).debugDescription,
            #"SayItDevError.refusal("he said \"no\"")"#
        )
    }
    test("refusal with empty explanation still produces a non-empty openAIMessage") {
        let empty = SayItDevError.refusal("")
        try assertTrue(!empty.openAIMessage.isEmpty, "empty refusal must not produce empty message")
        try assertEqual(empty.openAIMessage, "The on-device model refused the request: ")
        try assertEqual(empty.cliLabel, "[refusal]")
    }
    test("refusal localizedDescription equals openAIMessage for non-trivial text") {
        let err = SayItDevError.refusal("multi-sentence reason. Another clause.")
        try assertEqual((err as Error).localizedDescription, err.openAIMessage)
    }
    // Locale-independence of the typed refusal classification path.
    // The mirror string contains "refusal" regardless of the user's locale;
    // localizedMsg is rendered by Apple in whatever language the system is set to.
    // Each case must still classify as .refusal with the localized text preserved.
    let refusalLocaleFixtures: [(lang: String, localizedMsg: String)] = [
        ("en", "The model refused to answer."),
        ("de", "Das Modell hat die Antwort verweigert."),
        ("fr", "Le modele a refuse de repondre."),
        ("ja", "モデルは回答を拒否しました。"),
        ("zh", "模型拒绝回答。"),
    ]
    for fixture in refusalLocaleFixtures {
        test("refusal is detected and explanation preserved on \(fixture.lang) locale") {
            let err = FoundationModelsGenerationErrorStub(
                caseName: "refusal",
                localizedMsg: fixture.localizedMsg
            )
            let classified = SayItDevError.classify(err)
            if case .refusal(let text) = classified {
                try assertEqual(text, fixture.localizedMsg, "locale=\(fixture.lang)")
            } else {
                throw TestFailure("expected .refusal on \(fixture.lang), got \(classified)")
            }
        }
    }
    test("openAIMessage is non-empty for all cases") {
        let cases: [SayItDevError] = [.guardrailViolation, .refusal("text"), .contextOverflow,
                                    .rateLimited, .concurrentRequest, .assetsUnavailable,
                                    .toolExecution("tool failed"), .unknown("oops"),
                                    .unsupportedGuide, .decodingFailure("decode failed"),
                                    .unsupportedLanguage("Klingon")]
        for c in cases {
            try assertTrue(!c.openAIMessage.isEmpty, "\(c)")
        }
    }
    test("all MCPError variants map to toolExecution") {
        let variants: [MCPError] = [
            .invalidResponse("bad json"),
            .serverError("tool failed"),
            .toolNotFound("no such tool"),
            .processError("server died"),
            .timedOut("timed out after 5s"),
        ]
        for err in variants {
            let classified = SayItDevError.classify(err)
            if case .toolExecution(let msg) = classified {
                try assertTrue(!msg.isEmpty, "toolExecution message should not be empty for \(err)")
            } else {
                throw TestFailure("expected .toolExecution for \(err), got \(classified)")
            }
        }
    }
    test("MCPError descriptions match classification messages") {
        let err = MCPError.serverError("divide failed")
        try assertEqual(err.description, "divide failed")
        try assertEqual(SayItDevError.classify(err), .toolExecution("divide failed"))
    }
    test("MCPError Equatable works correctly") {
        try assertEqual(MCPError.timedOut("a"), MCPError.timedOut("a"))
        try assertTrue(MCPError.timedOut("a") != MCPError.timedOut("b"))
        try assertTrue(MCPError.timedOut("a") != MCPError.serverError("a"))
        try assertEqual(MCPError.toolNotFound("x"), MCPError.toolNotFound("x"))
    }
    test("toolExecution preserves original error message") {
        let msg = "Tool 'divide' failed: Error: division by zero"
        let err = SayItDevError.toolExecution(msg)
        try assertEqual(err.openAIMessage, msg)
        try assertEqual(err.httpStatusCode, 500)
        try assertEqual(err.openAIType, "server_error")
        try assertEqual(err.cliLabel, "[tool error]")
    }
    test("unsupportedLanguage error properties") {
        let err = SayItDevError.unsupportedLanguage("Klingon")
        try assertEqual(err.httpStatusCode, 400)
        try assertEqual(err.openAIType, "invalid_request_error")
        try assertEqual(err.cliLabel, "[unsupported language]")
        try assertTrue(err.openAIMessage.contains("Klingon"))
    }

    // --- unsupportedGuide (#41) ---

    test("unsupportedGuide error properties") {
        let err = SayItDevError.unsupportedGuide
        try assertEqual(err.cliLabel, "[unsupported guide]")
        try assertEqual(err.openAIType, "invalid_request_error")
        try assertEqual(err.httpStatusCode, 400)
        try assertTrue(!err.openAIMessage.isEmpty)
        try assertTrue(!err.isRetryable)
    }
    test("classify detects GenerationError.unsupportedGuide") {
        let err = FoundationModelsGenerationErrorStub(
            caseName: "unsupportedGuide",
            localizedMsg: "Nicht unterstuetzte Anleitung"
        )
        try assertEqual(SayItDevError.classify(err), .unsupportedGuide)
    }
    test("classify passthrough for unsupportedGuide") {
        try assertEqual(SayItDevError.classify(SayItDevError.unsupportedGuide), .unsupportedGuide)
    }

    // --- decodingFailure (#41) ---

    test("decodingFailure error properties") {
        let err = SayItDevError.decodingFailure("bad output")
        try assertEqual(err.cliLabel, "[decoding failure]")
        try assertEqual(err.openAIType, "server_error")
        try assertEqual(err.httpStatusCode, 500)
        try assertTrue(err.openAIMessage.contains("bad output"))
        try assertTrue(!err.isRetryable)
    }
    test("classify detects GenerationError.decodingFailure") {
        let err = FoundationModelsGenerationErrorStub(
            caseName: "decodingFailure",
            localizedMsg: "Dekodierungsfehler"
        )
        if case .decodingFailure = SayItDevError.classify(err) { } else {
            throw TestFailure("expected .decodingFailure")
        }
    }
    test("classify passthrough for decodingFailure") {
        if case .decodingFailure = SayItDevError.classify(SayItDevError.decodingFailure("x")) { } else {
            throw TestFailure("expected .decodingFailure passthrough")
        }
    }
}
