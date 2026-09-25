// ============================================================================
// VoiceHandlers.swift — OpenAI-compatible /v1/audio/* routes
// ============================================================================

import Foundation
import Hummingbird
import SayItDevCore
import SayItDevCLI

struct AudioSpeechRequest: Decodable {
    var model: String?
    var input: String
    var voice: String?
    var response_format: String?
    var speed: Double?
}

struct AudioTranscriptionResponse: Encodable {
    var text: String
}

struct AudioTranscriptionVerboseResponse: Encodable {
    struct Segment: Encodable {
        var text: String
        var start: Double
        var end: Double
    }
    var text: String
    var segments: [Segment]?
}

func handleAudioSpeech(_ request: Request, voiceConfig: VoiceConfig) async throws -> Response {
    let body = try await request.body.collect(upTo: BodyLimits.maxRequestBodyBytes)
    guard let data = body.getData(at: 0, length: body.readableBytes) else {
        return openAIError(status: .badRequest, message: "Empty request body", type: "invalid_request_error")
    }
    let decoded: AudioSpeechRequest
    do {
        decoded = try JSONDecoder().decode(AudioSpeechRequest.self, from: data)
    } catch {
        return openAIError(status: .badRequest, message: "Invalid JSON body", type: "invalid_request_error")
    }
    guard !decoded.input.isEmpty else {
        return openAIError(status: .badRequest, message: "'input' is required", type: "invalid_request_error")
    }
    var cfg = voiceConfig
    if let v = decoded.voice { cfg.voiceName = v }
    if let rf = decoded.response_format?.lowercased() {
        if rf == "mp3" || rf == "opus" || rf == "flac" {
            return openAIError(
                status: .badRequest,
                message: "On-device TTS cannot encode \(rf). Use wav, pcm, or aac.",
                type: "invalid_request_error"
            )
        }
        if let fmt = AudioOutputFormat.parse(rf) { cfg.audioFormat = fmt }
    }
    if let sp = decoded.speed {
        let clamped = min(4.0, max(0.25, sp))
        cfg.rate = Float(clamped)
    }
    let (audioData, contentType) = try await SpeechOutput.render(decoded.input, config: cfg)
    var headers = HTTPFields()
    headers[.contentType] = contentType
    headers[.contentLength] = String(audioData.count)
    return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(data: audioData)))
}

func handleAudioTranscription(_ request: Request, voiceConfig: VoiceConfig) async throws -> Response {
    let contentType = request.headers[.contentType]
    let body = try await request.body.collect(upTo: BodyLimits.maxAudioUploadBytes)
    guard body.readableBytes > 0 else {
        return openAIError(status: .badRequest, message: "Empty upload", type: "invalid_request_error")
    }
    guard let raw = body.getData(at: 0, length: body.readableBytes) else {
        return openAIError(status: .badRequest, message: "Invalid body", type: "invalid_request_error")
    }
    let ct = contentType ?? ""
    guard ct.lowercased().contains("multipart/form-data") else {
        return openAIError(status: .badRequest, message: "Content-Type must be multipart/form-data", type: "invalid_request_error")
    }
    let parts: [MultipartPart]
    do {
        parts = try MultipartFormData.parse(contentType: ct, body: raw)
    } catch {
        return openAIError(status: .badRequest, message: "Failed to parse multipart upload", type: "invalid_request_error")
    }
    guard let filePart = parts.first(where: { $0.name == "file" && !$0.body.isEmpty }) else {
        return openAIError(status: .badRequest, message: "Missing 'file' part", type: "invalid_request_error")
    }
    var cfg = voiceConfig
    if let lang = parts.first(where: { $0.name == "language" }).flatMap({ String(data: $0.body, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) }), !lang.isEmpty {
        cfg.locale = Locale(identifier: lang)
    }
    let responseFormat = parts.first(where: { $0.name == "response_format" })
        .flatMap { String(data: $0.body, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) }
        ?? "json"
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("sayitdev-upload-\(UUID().uuidString).audio")
    defer { try? FileManager.default.removeItem(at: tempURL) }
    try filePart.body.write(to: tempURL)
    let result: TranscriptionResult
    do {
        result = try await SpeechInput.transcribeFile(url: tempURL, config: cfg)
    } catch let e as SpeechInputError {
        switch e {
        case .permissionDenied(let msg):
            return openAIError(status: .forbidden, message: msg, type: "permission_error")
        default:
            return openAIError(status: .badRequest, message: e.localizedDescription, type: "invalid_request_error")
        }
    }
    switch responseFormat {
    case "text":
        var headers = HTTPFields()
        headers[.contentType] = "text/plain; charset=utf-8"
        return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: result.text)))
    case "verbose_json", "srt", "vtt":
        if responseFormat == "srt" || responseFormat == "vtt" {
            let formatted = formatTimedText(result, format: responseFormat)
            var headers = HTTPFields()
            headers[.contentType] = "text/plain; charset=utf-8"
            return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: formatted)))
        }
        let segs = result.segments?.map {
            AudioTranscriptionVerboseResponse.Segment(text: $0.text, start: $0.start, end: $0.end)
        }
        let payload = AudioTranscriptionVerboseResponse(text: result.text, segments: segs)
        return jsonResponse(jsonString(payload))
    default:
        return jsonResponse(jsonString(AudioTranscriptionResponse(text: result.text)))
    }
}

func handleAudioVoices() -> Response {
    jsonResponse(SpeechOutput.listVoicesJSON())
}

private func formatTimedText(_ result: TranscriptionResult, format: String) -> String {
    guard let segments = result.segments, !segments.isEmpty else { return result.text }
    if format == "srt" {
        return segments.enumerated().map { idx, seg in
            "\(idx + 1)\n\(formatSRTTime(seg.start)) --> \(formatSRTTime(seg.end))\n\(seg.text)\n"
        }.joined(separator: "\n")
    }
    return segments.map { seg in
        "\(formatVTTTime(seg.start)) --> \(formatVTTTime(seg.end))\n\(seg.text)\n"
    }.joined(separator: "\n")
}

private func formatSRTTime(_ t: TimeInterval) -> String {
    let h = Int(t) / 3600
    let m = (Int(t) % 3600) / 60
    let s = Int(t) % 60
    let ms = Int((t - Double(Int(t))) * 1000)
    return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
}

private func formatVTTTime(_ t: TimeInterval) -> String {
    let h = Int(t) / 3600
    let m = (Int(t) % 3600) / 60
    let s = Int(t) % 60
    let ms = Int((t - Double(Int(t))) * 1000)
    return String(format: "%02d:%02d:%02d.%03d", h, m, s, ms)
}

private func jsonString<T: Encodable>(_ value: T) -> String {
    let data = (try? JSONEncoder().encode(value)) ?? Data("{}".utf8)
    return String(data: data, encoding: .utf8) ?? "{}"
}
