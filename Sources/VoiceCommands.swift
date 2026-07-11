// ============================================================================
// VoiceCommands.swift — CLI entry points for --speak / --listen / --agent
// ============================================================================

import Foundation
import SayItDevCLI

enum VoiceCommands {
    static func runSpeak(text: String, config: VoiceConfig) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            printError("no text provided for --speak")
            throw ExitSignal.usage
        }
        try await SpeechOutput.speak(trimmed, config: config)
    }

    static func runListen(config: VoiceConfig) async throws {
        printStderr("Listening on default microphone (up to 30s)...")
        let text = try await SpeechInput.transcribeMic(config: config, maxDuration: 30)
        print(text)
    }
}

/// Lightweight typed exit for voice command validation
enum ExitSignal: Error {
    case usage
}
