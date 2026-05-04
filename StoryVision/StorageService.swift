import Foundation
import FirebaseStorage
#if canImport(UIKit)
import UIKit

struct StorageService {
    private static var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    private static var storiesRef: StorageReference {
        Storage.storage().reference().child("stories/\(deviceID)")
    }

    static func upload(image: UIImage, prompt: String) async throws -> Story {
        let id = UUID().uuidString
        let ref = storiesRef.child("\(id).jpg")

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw StorageServiceError.compressionFailed
        }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "prompt": prompt,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()

        return Story(id: id, prompt: prompt, imageURL: url, createdAt: Date())
    }

    static func fetchAllStories() async throws -> [Story] {
        let result = try await storiesRef.listAll()

        var stories: [Story] = []
        for item in result.items {
            async let metadataTask = item.getMetadata()
            async let urlTask = item.downloadURL()
            let (metadata, url) = try await (metadataTask, urlTask)

            let prompt = metadata.customMetadata?["prompt"] ?? ""
            let dateString = metadata.customMetadata?["createdAt"] ?? ""
            let date = ISO8601DateFormatter().date(from: dateString) ?? Date()
            let id = item.name.replacingOccurrences(of: ".jpg", with: "")

            stories.append(Story(id: id, prompt: prompt, imageURL: url, createdAt: date))
        }

        return stories.sorted { $0.createdAt > $1.createdAt }
    }
}

enum StorageServiceError: LocalizedError {
    case compressionFailed
    var errorDescription: String? { "Failed to compress image for upload." }
}
#endif
