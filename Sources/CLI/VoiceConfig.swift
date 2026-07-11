// ============================================================================
// VoiceConfig.swift — Shared voice defaults (flags + DEV_* env)
// ============================================================================

import Foundation

/// Output format for TTS rendering (server + CLI).
public enum AudioOutputFormat: String, Sendable, Equatable {
    case wav
    case pcm
    case aac

    public static func parse(_ raw: String) -> AudioOutputFormat? {
        AudioOutputFormat(rawValue: raw.lowercased())
    }
}

/// Resolved voice settings shared by CLI and server handlers.
public struct VoiceConfig: Sendable, Equatable {
    public var inputDeviceUID: String?
    public var voiceName: String?
    public var locale: Locale
    public var rate: Float?
    public var audioFormat: AudioOutputFormat
    public var timestamps: Bool

    public init(
        inputDeviceUID: String? = nil,
        voiceName: String? = nil,
        locale: Locale = .current,
        rate: Float? = nil,
        audioFormat: AudioOutputFormat = .wav,
        timestamps: Bool = false
    ) {
        self.inputDeviceUID = inputDeviceUID
        self.voiceName = voiceName
        self.locale = locale
        self.rate = rate
        self.audioFormat = audioFormat
        self.timestamps = timestamps
    }

    /// Merge CLI flags with environment defaults (flags win when set in parse).
    public static func resolve(from args: CLIArguments, env: [String: String]) -> VoiceConfig {
        var cfg = VoiceConfig()
        if let uid = args.inputDeviceUID ?? env["DEV_AUDIO_INPUT"].flatMap({ $0.isEmpty ? nil : $0 }) {
            cfg.inputDeviceUID = uid
        }
        if let voice = args.voiceName ?? env["DEV_TTS_VOICE"].flatMap({ $0.isEmpty ? nil : $0 }) {
            cfg.voiceName = voice
        }
        if let loc = args.localeID ?? env["DEV_STT_LOCALE"].flatMap({ $0.isEmpty ? nil : $0 }) {
            cfg.locale = Locale(identifier: loc)
        }
        if let r = args.ttsRate {
            cfg.rate = r
        } else if let raw = env["DEV_TTS_RATE"], let d = Double(raw), d > 0 {
            cfg.rate = Float(d)
        }
        if let fmt = args.audioFormat {
            cfg.audioFormat = fmt
        } else if let raw = env["DEV_TTS_FORMAT"], let f = AudioOutputFormat.parse(raw) {
            cfg.audioFormat = f
        }
        cfg.timestamps = args.timestamps
        return cfg
    }
}
