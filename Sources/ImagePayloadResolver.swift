// ============================================================================
// ImagePayloadResolver.swift — Resolve OpenAI and CLI image inputs to disk URLs
// ============================================================================

import Foundation
import SayItDevCore

enum ImagePayloadResolver {
    /// Resolves an OpenAI-style image_url string (data URI, file path, or file/http URL)
    /// into a local file URL on disk suitable for FoundationModels Attachment.
    static func resolve(urlString: String) async throws -> URL {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Data URI: data:image/png;base64,...
        if trimmed.hasPrefix("data:") {
            guard let commaIdx = trimmed.firstIndex(of: ",") else {
                throw SayItDevError.decodingFailure("Malformed data URI for image")
            }
            let meta = String(trimmed[..<commaIdx])
            let base64String = String(trimmed[trimmed.index(after: commaIdx)...])
            guard let data = Data(base64Encoded: base64String, options: [.ignoreUnknownCharacters]) else {
                throw SayItDevError.decodingFailure("Invalid base64 encoding in image data URI")
            }
            let ext: String
            if meta.contains("image/jpeg") || meta.contains("image/jpg") {
                ext = "jpg"
            } else if meta.contains("image/heic") {
                ext = "heic"
            } else {
                ext = "png"
            }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".\(ext)")
            try data.write(to: tempURL)
            return tempURL
        }

        // 2. file:// URL
        if let url = URL(string: trimmed), url.scheme == "file" {
            return url
        }

        // 3. Absolute local path
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }

        // 4. http(s) URL
        if let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" {
            let session = URLSession(configuration: .ephemeral)
            let (location, _) = try await session.download(from: url)
            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".\(ext)")
            try FileManager.default.moveItem(at: location, to: temp)
            return temp
        }

        // Relative local path
        return URL(fileURLWithPath: trimmed)
    }
}
