import Foundation
import SayItDevCore

func runMultipartFormDataTests() {
    test("parse simple multipart file upload") {
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        append("--BOUNDARY\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\n")
        append("Content-Type: audio/wav\r\n")
        append("\r\n")
        append("hello audio\r\n")
        append("--BOUNDARY--\r\n")
        let ct = "multipart/form-data; boundary=BOUNDARY"
        let parts = try MultipartFormData.parse(contentType: ct, body: body)
        try assertEqual(parts.count, 1)
        try assertEqual(parts[0].name, "file")
        try assertEqual(parts[0].filename, "a.wav")
        try assertEqual(String(data: parts[0].body, encoding: .utf8), "hello audio")
    }

    test("extract boundary from content-type") {
        let b = MultipartFormData.extractBoundary(from: "multipart/form-data; boundary=----abc")
        try assertEqual(b, "----abc")
    }
}
