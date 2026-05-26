import Foundation

class OpenAICompatibleTranscriptionService {
    /// Chunk size used to stream the audio file into the multipart temp body.
    /// 1 MiB balances throughput with bounded peak memory usage.
    private static let multipartReadChunkSize = 1 * 1024 * 1024

    func transcribe(audioURL: URL, model: CustomCloudModel, resourceTimeout: TimeInterval) async throws -> String {
        guard let url = URL(string: model.apiEndpoint) else {
            throw NSError(domain: "CustomWhisperTranscriptionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint URL"])
        }
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw CloudTranscriptionError.audioFileNotFound
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(model.apiKey)", forHTTPHeaderField: "Authorization")

        // Model-aware: resolves the inherit-from-Settings sentinel AND
        // validates the resulting code against the custom model's
        // supported list so a Settings choice like "pt-BR" doesn't reach
        // a provider that only ships "pt".
        let resolvedLanguage = LanguageResolver.effectiveSTTCode(for: model)
        let language = resolvedLanguage.isEmpty ? "auto" : resolvedLanguage

        let bodyURL = try writeMultipartBody(audioURL: audioURL, modelName: model.modelName, language: language, boundary: boundary)
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = max(resourceTimeout, 60)
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.upload(for: request, fromFile: bodyURL)
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut {
            throw CloudTranscriptionError.timeout(seconds: resourceTimeout)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.networkError(URLError(.badServerResponse))
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
            throw CloudTranscriptionError.apiRequestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            return try JSONDecoder().decode(TranscriptionResponse.self, from: data).text
        } catch {
            throw CloudTranscriptionError.noTranscriptionReturned
        }
    }

    /// Writes the multipart body to a temp file by streaming the audio file in chunks.
    ///
    /// Previously the entire multipart envelope (headers + raw audio bytes + footer)
    /// was built in a single `Data` in memory. For long recordings this kept the full
    /// audio resident in process heap during the upload — wasteful and unnecessary,
    /// since URLSession can already stream from a file via `upload(for:fromFile:)`.
    private func writeMultipartBody(audioURL: URL, modelName: String, language: String, boundary: String) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiceink-multipart-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)

        let writer: FileHandle
        do {
            writer = try FileHandle(forWritingTo: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }

        do {
            let crlf = "\r\n"
            let selectedLanguage = language
            let prompt = UserDefaults.standard.string(forKey: "TranscriptionPrompt") ?? ""

            func write(_ string: String) throws {
                guard let data = string.data(using: .utf8) else {
                    throw CloudTranscriptionError.dataEncodingError
                }
                try writer.write(contentsOf: data)
            }
            func writeField(_ name: String, _ value: String) throws {
                try write("--\(boundary)\(crlf)")
                try write("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)")
                try write(value)
                try write(crlf)
            }

            // Audio file part header
            try write("--\(boundary)\(crlf)")
            try write("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\(crlf)")
            try write("Content-Type: audio/wav\(crlf)\(crlf)")

            // Stream the audio bytes from disk in bounded chunks instead of slurping
            // the whole file into memory.
            let reader = try FileHandle(forReadingFrom: audioURL)
            defer { try? reader.close() }
            while true {
                let chunk = try reader.read(upToCount: Self.multipartReadChunkSize) ?? Data()
                if chunk.isEmpty { break }
                try writer.write(contentsOf: chunk)
            }
            try write(crlf)

            // Trailing form fields
            try writeField("model", modelName)
            try writeField("response_format", "json")
            try writeField("temperature", "0")
            if selectedLanguage != "auto" && !selectedLanguage.isEmpty {
                try writeField("language", selectedLanguage)
            }
            if !prompt.isEmpty {
                try writeField("prompt", prompt)
            }
            try write("--\(boundary)--\(crlf)")

            try writer.close()
            return tempURL
        } catch {
            try? writer.close()
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
        let language: String?
        let duration: Double?
    }
}
