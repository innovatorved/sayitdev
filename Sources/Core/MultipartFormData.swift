// ============================================================================
// MultipartFormData.swift — Minimal multipart/form-data parser for STT uploads
// ============================================================================

import Foundation

package struct MultipartPart: Sendable, Equatable {
    package var name: String?
    package var filename: String?
    package var contentType: String?
    package var body: Data
}

package enum MultipartFormDataError: Error, Sendable, Equatable {
    case missingBoundary
    case invalidBody
    case tooManyParts
}

package enum MultipartFormData {
    package static let maxParts = 32

    /// Parse `multipart/form-data` body using the boundary from Content-Type.
    package static func parse(contentType: String?, body: Data) throws -> [MultipartPart] {
        guard let contentType, let boundary = extractBoundary(from: contentType) else {
            throw MultipartFormDataError.missingBoundary
        }
        let marker = Data("--\(boundary)".utf8)
        let endMarker = Data("--\(boundary)--".utf8)
        guard body.count >= marker.count else { throw MultipartFormDataError.invalidBody }

        var parts: [MultipartPart] = []
        var searchStart = body.startIndex
        while searchStart < body.endIndex {
            guard let range = body.range(of: marker, in: searchStart..<body.endIndex) else { break }
            searchStart = range.upperBound
            if body[searchStart..<min(searchStart + 2, body.endIndex)] == Data("\r\n".utf8) {
                searchStart = body.index(searchStart, offsetBy: 2)
            }
            guard let next = body.range(of: marker, in: searchStart..<body.endIndex) else { break }
            let chunk = body[searchStart..<next.lowerBound]
            if chunk == Data("--".utf8) || dataSuffixEquals(chunk, suffix: Data("--".utf8)) { break }
            if let part = parsePart(chunk) {
                parts.append(part)
                if parts.count > maxParts { throw MultipartFormDataError.tooManyParts }
            }
            searchStart = next.lowerBound
        }
        if parts.isEmpty, !dataSuffixEquals(body, suffix: endMarker), !body.contains(marker) {
            throw MultipartFormDataError.invalidBody
        }
        return parts
    }

    package static func extractBoundary(from contentType: String) -> String? {
        for segment in contentType.split(separator: ";") {
            let s = segment.trimmingCharacters(in: .whitespaces)
            if s.lowercased().hasPrefix("boundary=") {
                var b = String(s.dropFirst("boundary=".count))
                if b.hasPrefix("\""), b.hasSuffix("\""), b.count >= 2 {
                    b = String(b.dropFirst().dropLast())
                }
                return b.isEmpty ? nil : b
            }
        }
        return nil
    }

    private static func parsePart(_ chunk: Data) -> MultipartPart? {
        guard let sep = chunk.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = chunk[..<sep.lowerBound]
        let body = chunk[sep.upperBound...]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        var name: String?
        var filename: String?
        var contentType: String?
        for line in headerText.split(separator: "\r\n") {
            let lineStr = String(line)
            if lineStr.lowercased().hasPrefix("content-disposition:") {
                for param in lineStr.dropFirst("content-disposition:".count).split(separator: ";") {
                    let p = param.trimmingCharacters(in: .whitespaces)
                    if p.lowercased().hasPrefix("name=") {
                        name = stripQuotes(String(p.dropFirst(5)))
                    } else if p.lowercased().hasPrefix("filename=") {
                        filename = stripQuotes(String(p.dropFirst(9)))
                    }
                }
            } else if lineStr.lowercased().hasPrefix("content-type:") {
                contentType = lineStr.dropFirst("content-type:".count).trimmingCharacters(in: .whitespaces)
            }
        }
        var trimmedBody = Data(body)
        if trimmedBody.count >= 2, trimmedBody.suffix(2) == Data("\r\n".utf8) {
            trimmedBody.removeLast(2)
        }
        return MultipartPart(name: name, filename: filename, contentType: contentType, body: trimmedBody)
    }

    private static func dataSuffixEquals(_ data: Data, suffix: Data) -> Bool {
        guard data.count >= suffix.count else { return false }
        return data.suffix(suffix.count) == suffix
    }

    private static func stripQuotes(_ s: String) -> String {
        if s.hasPrefix("\""), s.hasSuffix("\""), s.count >= 2 {
            return String(s.dropFirst().dropLast())
        }
        return s
    }
}
