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

        return Story(id: id, prompt: prompt, imageURL: url, audioURL: nil, createdAt: Date())
    }

    // MARK: - Audio

    static func uploadAudio(data: Data, storyID: String) async throws -> URL {
        let ref = storiesRef.child("\(storyID).mp3")

        let metadata = StorageMetadata()
        metadata.contentType = "audio/mpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL()
    }

    static func updateAudioURL(_ audioURL: URL, forStoryID storyID: String) async throws {
        let ref = storiesRef.child("\(storyID).jpg")
        let metadata = StorageMetadata()
        metadata.customMetadata = ["audioURL": audioURL.absoluteString]
        _ = try await ref.updateMetadata(metadata)
    }

    // MARK: - Fetch

    static func fetchAllStories() async throws -> [Story] {
        let result = try await storiesRef.listAll()

        // Only process image files; audio files are resolved via metadata
        let imageItems = result.items.filter { $0.name.hasSuffix(".jpg") }

        var stories: [Story] = []
        for item in imageItems {
            async let metadataTask = item.getMetadata()
            async let urlTask = item.downloadURL()
            let (metadata, url) = try await (metadataTask, urlTask)

            let prompt = metadata.customMetadata?["prompt"] ?? ""
            let dateString = metadata.customMetadata?["createdAt"] ?? ""
            let date = ISO8601DateFormatter().date(from: dateString) ?? Date()
            let id = item.name.replacingOccurrences(of: ".jpg", with: "")

            let audioURLString = metadata.customMetadata?["audioURL"]
            let audioURL = audioURLString.flatMap { URL(string: $0) }

            stories.append(Story(id: id, prompt: prompt, imageURL: url, audioURL: audioURL, createdAt: date))
        }

        return stories.sorted { $0.createdAt > $1.createdAt }
    }
}

enum StorageServiceError: LocalizedError {
    case compressionFailed
    var errorDescription: String? { "Failed to compress image for upload." }
}
#endif
