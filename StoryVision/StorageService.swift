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

    // Upload one image as part of a story. index determines sort order (00, 01, …).
    static func uploadImage(
        image: UIImage,
        storyID: String,
        prompt: String,
        storyCreatedAt: Date,
        index: Int
    ) async throws -> URL {
        let filename = String(format: "%02d.jpg", index)
        let ref = storiesRef.child("\(storyID)/\(filename)")

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw StorageServiceError.compressionFailed
        }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "prompt": prompt,
            "createdAt": ISO8601DateFormatter().string(from: storyCreatedAt)
        ]

        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL()
    }

    static func fetchAllStories() async throws -> [Story] {
        let result = try await storiesRef.listAll()

        var stories: [Story] = []
        for storyPrefix in result.prefixes {
            let storyResult = try await storyPrefix.listAll()
            let sortedItems = storyResult.items.sorted { $0.name < $1.name }
            guard !sortedItems.isEmpty else { continue }

            // prompt + createdAt metadata lives on every image; read from the first
            let firstMeta = try await sortedItems[0].getMetadata()
            let prompt = firstMeta.customMetadata?["prompt"] ?? ""
            let dateString = firstMeta.customMetadata?["createdAt"] ?? ""
            let date = ISO8601DateFormatter().date(from: dateString) ?? Date()

            var urls: [URL] = []
            for item in sortedItems {
                if let url = try? await item.downloadURL() {
                    urls.append(url)
                }
            }
            guard !urls.isEmpty else { continue }

            stories.append(Story(id: storyPrefix.name, prompt: prompt, imageURLs: urls, createdAt: date))
        }

        return stories.sorted { $0.createdAt > $1.createdAt }
    }
}

enum StorageServiceError: LocalizedError {
    case compressionFailed
    var errorDescription: String? { "Failed to compress image for upload." }
}
#endif
