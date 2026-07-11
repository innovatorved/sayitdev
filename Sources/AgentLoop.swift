// ============================================================================
// AgentLoop.swift — Simple voice agent: listen → LLM → speak
// ============================================================================

import Foundation
import SayItDevCLI

enum AgentLoop {
    static func run(systemPrompt: String?, options: SessionOptions, config: VoiceConfig) async throws {
        printStderr("SayItDev agent — speak your question (Ctrl+C to quit)")
        while true {
            if Task.isCancelled { break }
            printStderr("Listening...")
            let transcript: String
            do {
                transcript = try await SpeechInput.transcribeMic(config: config)
            } catch SpeechInputError.emptyAudio {
                printStderr("(no speech detected, listening again...)")
                continue
            }
            printStderr("You: \(transcript)")
            let reply = try await generateReply(transcript: transcript, systemPrompt: systemPrompt, options: options)
            print(reply)
            printStderr("SayItDev: speaking reply...")
            try await SpeechOutput.speak(reply, config: config)
        }
    }

    private static func generateReply(transcript: String, systemPrompt: String?, options: SessionOptions) async throws -> String {
        let session = makeSession(systemPrompt: systemPrompt, options: options)
        let response = try await session.respond(to: transcript, options: makeGenerationOptions(options))
        return response.content
    }
}
