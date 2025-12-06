import Foundation

actor WhisperService {
    private let apiKey: String
    private let endpoint: String
    private let model: String

    init(
        apiKey: String = Config.openAIAPIKey,
        endpoint: String = Config.whisperEndpoint,
        model: String = Config.whisperModel
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
    }

    struct TranscriptionResponse: Codable {
        let text: String
    }

    struct APIError: Codable {
        let error: ErrorDetail

        struct ErrorDetail: Codable {
            let message: String
            let type: String?
            let code: String?
        }
    }

    enum WhisperError: LocalizedError {
        case invalidURL
        case invalidAPIKey
        case fileNotFound
        case networkError(Error)
        case apiError(String)
        case decodingError
        case rateLimited
        case serverError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .invalidAPIKey:
                return "Invalid API key"
            case .fileNotFound:
                return "Audio file not found"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .apiError(let message):
                return "API error: \(message)"
            case .decodingError:
                return "Failed to decode response"
            case .rateLimited:
                return "Rate limited. Please try again later."
            case .serverError(let code):
                return "Server error (code: \(code))"
            }
        }
    }

    func transcribe(audioURL: URL, language: String? = nil, retryCount: Int = 3) async throws -> String {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw WhisperError.fileNotFound
        }

        guard let url = URL(string: endpoint) else {
            throw WhisperError.invalidURL
        }

        guard !apiKey.isEmpty, apiKey != "YOUR_OPENAI_API_KEY" else {
            throw WhisperError.invalidAPIKey
        }

        var lastError: Error?

        for attempt in 0..<retryCount {
            do {
                let result = try await performTranscription(url: url, audioURL: audioURL, language: language)
                return result
            } catch WhisperError.rateLimited {
                let delay = pow(2.0, Double(attempt)) // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                lastError = WhisperError.rateLimited
            } catch WhisperError.serverError(let code) where code >= 500 {
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                lastError = WhisperError.serverError(code)
            } catch {
                throw error
            }
        }

        throw lastError ?? WhisperError.networkError(NSError(domain: "", code: -1))
    }

    private func performTranscription(url: URL, audioURL: URL, language: String?) async throws -> String {
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        // Response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        // Language (optional)
        if let language = language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }

        // Audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.networkError(NSError(domain: "", code: -1))
        }

        switch httpResponse.statusCode {
        case 200:
            if let result = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) {
                return result.text
            }
            throw WhisperError.decodingError

        case 401:
            throw WhisperError.invalidAPIKey

        case 429:
            throw WhisperError.rateLimited

        case 500...599:
            throw WhisperError.serverError(httpResponse.statusCode)

        default:
            if let error = try? JSONDecoder().decode(APIError.self, from: data) {
                throw WhisperError.apiError(error.error.message)
            }
            throw WhisperError.apiError("Unknown error (code: \(httpResponse.statusCode))")
        }
    }
}
