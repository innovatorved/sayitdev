// ============================================================================
// StdinReadPolicy.swift — When piped stdin should be consumed (#speak hang fix)
// Part of SayItDevCLI - no FoundationModels dependency
// ============================================================================

import Foundation

/// Pure policy for whether the executable should read piped stdin as prompt/speak text.
public enum StdinReadPolicy {
    /// Whether to read piped stdin for this mode when stdin is not a TTY.
    public static func shouldReadPipedStdin(mode: CLIArguments.Mode, promptEmpty: Bool) -> Bool {
        switch mode {
        case .speak:
            return promptEmpty
        case .single, .stream, .countTokens:
            return true
        case .serve, .benchmark, .modelInfo, .update, .listen, .transcribe,
             .chat, .help, .version, .release, .demos, .completions:
            return false
        }
    }
}
