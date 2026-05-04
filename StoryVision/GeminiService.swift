import Foundation
#if canImport(UIKit)
import UIKit

struct ImageService {
    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-fast-generate-001:predict"

    static func generateImage(from prompt: String) async throws -> UIImage {
        guard let url = URL(string: "\(endpoint)?key=\(Config.geminiAPIKey)") else {
            throw ImageServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "instances": [["prompt": prompt]],
            "parameters": ["sampleCount": 1, "aspectRatio": "16:9"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let message = String(data: data, encoding: .utf8) {
                throw ImageServiceError.serverError(message)
            }
            throw ImageServiceError.requestFailed
        }

        let result = try JSONDecoder().decode(ImagenResponse.self, from: data)

        guard
            let prediction = result.predictions.first,
            let imageData = Data(base64Encoded: prediction.bytesBase64Encoded),
            let image = UIImage(data: imageData)
        else {
            throw ImageServiceError.invalidResponse
        }

        return image
    }
}

enum ImageServiceError: LocalizedError {
    case invalidURL
    case requestFailed
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid API URL."
        case .requestFailed:        return "Request failed. Check your API key."
        case .invalidResponse:      return "Could not decode the generated image."
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}

private struct ImagenResponse: Decodable {
    let predictions: [ImagenPrediction]
}

private struct ImagenPrediction: Decodable {
    let bytesBase64Encoded: String
    let mimeType: String
}
#endif
