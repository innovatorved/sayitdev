// ============================================================================
// VoiceCommands.swift — CLI entry points for --speak / --listen / --transcribe
// ============================================================================

import Foundation
import SayItDevCLI
import SayItDevCore

enum VoiceCommands {
    static func runSpeak(text: String, config: VoiceConfig) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            printError("no text provided for --speak")
            throw ExitSignal.usage
        }
        try await SpeechOutput.speak(trimmed, config: config)
    }

    static func runTranscribe(path: String, config: VoiceConfig) async throws {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            printError("no audio file provided for --transcribe")
            throw ExitSignal.usage
        }
        let url = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            printError("file not found: \(url.path)")
            throw ExitSignal.usage
        }
        let result = try await SpeechInput.transcribeFile(url: url, config: config)
        if config.timestamps, let segments = result.segments, !segments.isEmpty {
            for seg in segments {
                let stamp = String(format: "[%.2f-%.2f] ", seg.start, seg.end)
                print(stamp + seg.text)
            }
        } else {
            print(result.text)
        }
    }

    static func runListen(config: VoiceConfig) async throws {
        printStderr("Listening… speak now (live transcript; stops when you pause)")
        final class DisplayState: @unchecked Sendable {
            var lastDisplayed = ""
        }
        let display = DisplayState()
        let text = try await SpeechInput.transcribeMic(config: config) { partial in
            let trimmed = partial.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != display.lastDisplayed else { return }
            display.lastDisplayed = trimmed
            fputs(LiveTranscriptLine.overwrite(trimmed), stdout)
            fflush(stdout)
        }
        if display.lastDisplayed.isEmpty {
            print(text)
        } else {
            fputs("\n", stdout)
            fflush(stdout)
        }
    }
}

/// Lightweight typed exit for voice command validation
enum ExitSignal: Error {
    case usage
}
