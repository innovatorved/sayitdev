// ============================================================================
// SayItDevErrorMessageTests.swift — Exact-string lockdown for every public error
// message in SayItDevCore. This is the baseline for adding LocalizedError in #105:
// when we add `errorDescription`, it must produce these same strings (or the
// change must be deliberate and visible in this test's diff).
//
// Covers:
//   - SayItDevError.openAIMessage (all 11 cases)
//   - SayItDevError.cliLabel, .openAIType, .httpStatusCode (stable enumerations)
//   - MCPError.description / errorDescription (all 5 cases)
//   - ChatRequestValidationFailure.message and .event (all 6 cases)
//   - UnsupportedChatParameter.name and .message (all 5 cases)
// ============================================================================

import Foundation
import SayItDevCore

func runSayItDevErrorMessageTests() {
    // MARK: - SayItDevError.openAIMessage (the user-visible HTTP error body)

    test("SayItDevError.guardrailViolation.openAIMessage") {
        try assertEqual(
            SayItDevError.guardrailViolation.openAIMessage,
            "The request was blocked by Apple's safety guardrails. Try rephrasing."
        )
    }
    test("SayItDevError.refusal.openAIMessage embeds the explanation") {
        try assertEqual(
            SayItDevError.refusal("I cannot answer that question.").openAIMessage,
            "The on-device model refused the request: I cannot answer that question."
        )
    }
    test("SayItDevError.contextOverflow.openAIMessage") {
        // No hardcoded window size (#330): the size is dynamic everywhere
        // else (TokenCounter.contextSize), and a pinned "4096" here becomes
        // a lie the day the OS reports a different window (OS 27 / #192).
        try assertEqual(
            SayItDevError.contextOverflow.openAIMessage,
            "Input exceeds the model's context window. Shorten the conversation history."
        )
    }
    test("SayItDevError.rateLimited.openAIMessage") {
        try assertEqual(
            SayItDevError.rateLimited.openAIMessage,
            "Apple Intelligence is rate limited. Retry after a few seconds."
        )
    }
    test("SayItDevError.concurrentRequest.openAIMessage") {
        try assertEqual(
            SayItDevError.concurrentRequest.openAIMessage,
            "Apple Intelligence is busy with another request. Retry shortly."
        )
    }
    test("SayItDevError.assetsUnavailable.openAIMessage") {
        try assertEqual(
            SayItDevError.assetsUnavailable.openAIMessage,
            "Model assets are loading. Try again in a moment."
        )
    }
    test("SayItDevError.unsupportedGuide.openAIMessage") {
        try assertEqual(
            SayItDevError.unsupportedGuide.openAIMessage,
            "The requested generation guide is not supported by this model."
        )
    }
    test("SayItDevError.decodingFailure.openAIMessage embeds the detail") {
        try assertEqual(
            SayItDevError.decodingFailure("bad JSON").openAIMessage,
            "Model output could not be decoded: bad JSON"
        )
    }
    test("SayItDevError.unsupportedLanguage.openAIMessage embeds the detail") {
        try assertEqual(
            SayItDevError.unsupportedLanguage("tlh").openAIMessage,
            "Unsupported language: tlh"
        )
    }
    test("SayItDevError.toolExecution.openAIMessage passes the detail through verbatim") {
        try assertEqual(
            SayItDevError.toolExecution("calculator exploded").openAIMessage,
            "calculator exploded"
        )
    }
    test("SayItDevError.unknown.openAIMessage passes the detail through verbatim") {
        try assertEqual(
            SayItDevError.unknown("mystery").openAIMessage,
            "mystery"
        )
    }

    // MARK: - SayItDevError.cliLabel (terminal prefix users see)

    test("SayItDevError cliLabel lockdown for every case") {
        try assertEqual(SayItDevError.guardrailViolation.cliLabel,  "[guardrail]")
        try assertEqual(SayItDevError.refusal("x").cliLabel,        "[refusal]")
        try assertEqual(SayItDevError.contextOverflow.cliLabel,     "[context overflow]")
        try assertEqual(SayItDevError.rateLimited.cliLabel,         "[rate limited]")
        try assertEqual(SayItDevError.concurrentRequest.cliLabel,   "[busy]")
        try assertEqual(SayItDevError.assetsUnavailable.cliLabel,   "[model loading]")
        try assertEqual(SayItDevError.unsupportedGuide.cliLabel,    "[unsupported guide]")
        try assertEqual(SayItDevError.decodingFailure("x").cliLabel,"[decoding failure]")
        try assertEqual(SayItDevError.unsupportedLanguage("x").cliLabel, "[unsupported language]")
        try assertEqual(SayItDevError.toolExecution("x").cliLabel,  "[tool error]")
        try assertEqual(SayItDevError.unknown("x").cliLabel,        "[error]")
    }

    // MARK: - SayItDevError.openAIType (JSON error payload "type" field — wire contract)

    test("SayItDevError openAIType lockdown for every case") {
        try assertEqual(SayItDevError.guardrailViolation.openAIType,  "content_policy_violation")
        try assertEqual(SayItDevError.refusal("x").openAIType,        "content_policy_violation")
        try assertEqual(SayItDevError.contextOverflow.openAIType,     "context_length_exceeded")
        try assertEqual(SayItDevError.rateLimited.openAIType,         "rate_limit_error")
        try assertEqual(SayItDevError.concurrentRequest.openAIType,   "rate_limit_error")
        try assertEqual(SayItDevError.assetsUnavailable.openAIType,   "server_error")
        try assertEqual(SayItDevError.unsupportedGuide.openAIType,    "invalid_request_error")
        try assertEqual(SayItDevError.decodingFailure("x").openAIType,"server_error")
        try assertEqual(SayItDevError.unsupportedLanguage("x").openAIType, "invalid_request_error")
        try assertEqual(SayItDevError.toolExecution("x").openAIType,  "server_error")
        try assertEqual(SayItDevError.unknown("x").openAIType,        "server_error")
    }

    // MARK: - SayItDevError.httpStatusCode (wire contract)

    test("SayItDevError httpStatusCode lockdown for every case") {
        try assertEqual(SayItDevError.guardrailViolation.httpStatusCode,  400)
        // Output-side refusal is HTTP 200 per OpenAI wire format: the response
        // carries finish_reason=content_filter and the refusal text on the
        // assistant message. Not an HTTP-level error.
        try assertEqual(SayItDevError.refusal("x").httpStatusCode,        200)
        try assertEqual(SayItDevError.contextOverflow.httpStatusCode,     400)
        try assertEqual(SayItDevError.rateLimited.httpStatusCode,         429)
        try assertEqual(SayItDevError.concurrentRequest.httpStatusCode,   429)
        try assertEqual(SayItDevError.assetsUnavailable.httpStatusCode,   503)
        try assertEqual(SayItDevError.unsupportedGuide.httpStatusCode,    400)
        try assertEqual(SayItDevError.decodingFailure("x").httpStatusCode,500)
        try assertEqual(SayItDevError.unsupportedLanguage("x").httpStatusCode, 400)
        try assertEqual(SayItDevError.toolExecution("x").httpStatusCode,  500)
        try assertEqual(SayItDevError.unknown("x").httpStatusCode,        500)
    }

    // MARK: - MCPError (already LocalizedError today — lock both surfaces)

    test("MCPError.description passes the detail through for every case") {
        try assertEqual(MCPError.invalidResponse("no json").description,  "no json")
        try assertEqual(MCPError.serverError("500 inside").description,   "500 inside")
        try assertEqual(MCPError.toolNotFound("add").description,         "add")
        try assertEqual(MCPError.processError("pipe broken").description, "pipe broken")
        try assertEqual(MCPError.timedOut("after 30s").description,       "after 30s")
    }

    test("MCPError.errorDescription equals .description for every case") {
        try assertEqual(MCPError.invalidResponse("x").errorDescription,  "x")
        try assertEqual(MCPError.serverError("x").errorDescription,      "x")
        try assertEqual(MCPError.toolNotFound("x").errorDescription,     "x")
        try assertEqual(MCPError.processError("x").errorDescription,     "x")
        try assertEqual(MCPError.timedOut("x").errorDescription,         "x")
    }

    test("SayItDevError.localizedDescription equals openAIMessage for every case") {
        let cases: [SayItDevError] = [
            .guardrailViolation,
            .refusal("model said no"),
            .contextOverflow,
            .rateLimited,
            .concurrentRequest,
            .assetsUnavailable,
            .unsupportedGuide,
            .decodingFailure("bad JSON"),
            .unsupportedLanguage("tlh"),
            .toolExecution("calculator exploded"),
            .unknown("mystery"),
        ]
        for error in cases {
            try assertEqual((error as Error).localizedDescription, error.openAIMessage)
        }
    }

    // MARK: - ChatRequestValidationFailure.message (HTTP 400 body for bad requests)

    test("ChatRequestValidationFailure.message for every case") {
        try assertEqual(
            ChatRequestValidationFailure.emptyMessages.message,
            "'messages' must contain at least one message"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidLastRole.message,
            "Last message must have role 'user' or 'tool'"
        )
        try assertEqual(
            ChatRequestValidationFailure.imageContent.message,
            "Image content is not supported by the Apple on-device model"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidParameterValue("nope").message,
            "nope"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidModel("gpt-5").message,
            "The model 'gpt-5' does not exist. The only available model is 'sayitdev-on-device'."
        )
        // unsupportedParameter delegates to the parameter's own message —
        // sampled here, fully covered below.
        try assertEqual(
            ChatRequestValidationFailure.unsupportedParameter(.logprobs).message,
            "Parameter 'logprobs' is not supported by Apple's on-device model."
        )
    }

    // MARK: - ChatRequestValidationFailure.event (debug/log line)

    test("ChatRequestValidationFailure.event for every case") {
        try assertEqual(
            ChatRequestValidationFailure.emptyMessages.event,
            "validation failed: empty messages"
        )
        try assertEqual(
            ChatRequestValidationFailure.unsupportedParameter(.stop).event,
            "validation failed: unsupported parameter stop"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidLastRole.event,
            "validation failed: last role != user/tool"
        )
        try assertEqual(
            ChatRequestValidationFailure.imageContent.event,
            "rejected: image content"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidParameterValue("temperature<0").event,
            "validation failed: temperature<0"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidModel("gpt-5").event,
            "validation failed: unknown model gpt-5"
        )
    }

    // MARK: - UnsupportedChatParameter (name + message)

    test("UnsupportedChatParameter.name matches the JSON field name") {
        try assertEqual(UnsupportedChatParameter.logprobs.name,          "logprobs")
        try assertEqual(UnsupportedChatParameter.n.name,                 "n")
        try assertEqual(UnsupportedChatParameter.stop.name,              "stop")
        try assertEqual(UnsupportedChatParameter.presencePenalty.name,   "presence_penalty")
        try assertEqual(UnsupportedChatParameter.frequencyPenalty.name,  "frequency_penalty")
    }

    test("UnsupportedChatParameter.message for every case") {
        try assertEqual(
            UnsupportedChatParameter.logprobs.message,
            "Parameter 'logprobs' is not supported by Apple's on-device model."
        )
        try assertEqual(
            UnsupportedChatParameter.n.message,
            "Parameter 'n' is not supported by Apple's on-device model. Only n=1 is allowed."
        )
        try assertEqual(
            UnsupportedChatParameter.stop.message,
            "Parameter 'stop' is not supported by Apple's on-device model."
        )
        try assertEqual(
            UnsupportedChatParameter.presencePenalty.message,
            "Parameter 'presence_penalty' is not supported by Apple's on-device model."
        )
        try assertEqual(
            UnsupportedChatParameter.frequencyPenalty.message,
            "Parameter 'frequency_penalty' is not supported by Apple's on-device model."
        )
    }

    // MARK: - Retryability (wire-relevant, affects client retry logic)

    test("SayItDevError.isRetryable lockdown for every case") {
        try assertEqual(SayItDevError.guardrailViolation.isRetryable,  false)
        try assertEqual(SayItDevError.refusal("x").isRetryable,        false)
        try assertEqual(SayItDevError.contextOverflow.isRetryable,     false)
        try assertEqual(SayItDevError.rateLimited.isRetryable,         true)
        try assertEqual(SayItDevError.concurrentRequest.isRetryable,   true)
        try assertEqual(SayItDevError.assetsUnavailable.isRetryable,   true)
        try assertEqual(SayItDevError.unsupportedGuide.isRetryable,    false)
        try assertEqual(SayItDevError.decodingFailure("x").isRetryable,false)
        try assertEqual(SayItDevError.unsupportedLanguage("x").isRetryable, false)
        try assertEqual(SayItDevError.toolExecution("x").isRetryable,  false)
        try assertEqual(SayItDevError.unknown("x").isRetryable,        false)
    }

    test("isRetryableError(_:) mirrors SayItDevError.isRetryable for classified errors") {
        try assertEqual(isRetryableError(SayItDevError.rateLimited),        true)
        try assertEqual(isRetryableError(SayItDevError.concurrentRequest),  true)
        try assertEqual(isRetryableError(SayItDevError.assetsUnavailable),  true)
        try assertEqual(isRetryableError(SayItDevError.contextOverflow),    false)
        try assertEqual(isRetryableError(SayItDevError.guardrailViolation), false)
        try assertEqual(isRetryableError(SayItDevError.refusal("x")),       false)
    }
}
