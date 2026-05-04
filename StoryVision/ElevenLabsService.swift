import Foundation

struct ElevenLabsVoice: Identifiable, Decodable {
    let voice_id: String
    let name: String

    var id: String { voice_id }
}

struct ElevenLabsService {
    private static let baseURL = "https://api.elevenlabs.io/v1"
    private static let model = "eleven_multilingual_v2"

    // MARK: - Text to Speech

    static func synthesize(text: String, voiceID: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/text-to-speech/\(voiceID)") else {
            throw ElevenLabsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            "model_id": model,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let message = String(data: data, encoding: .utf8) {
                throw ElevenLabsError.serverError(message)
            }
            throw ElevenLabsError.requestFailed
        }

        return data
    }

    // MARK: - Fetch Voices

    static func fetchVoices() async throws -> [ElevenLabsVoice] {
        guard let url = URL(string: "\(baseURL)/voices") else {
            throw ElevenLabsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(Config.elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ElevenLabsError.requestFailed
        }

        let result = try JSONDecoder().decode(VoicesResponse.self, from: data)
        return result.voices.sorted { $0.name < $1.name }
    }
}

enum ElevenLabsError: LocalizedError {
    case invalidURL
    case requestFailed
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid ElevenLabs API URL."
        case .requestFailed:        return "ElevenLabs request failed. Check your API key."
        case .serverError(let msg): return "ElevenLabs error: \(msg)"
        }
    }
}

private struct VoicesResponse: Decodable {
    let voices: [ElevenLabsVoice]
}
