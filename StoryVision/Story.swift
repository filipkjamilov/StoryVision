import Foundation

struct Story: Identifiable {
    let id: String
    let prompt: String
    let imageURLs: [URL]
    let audioURL: URL?
    let createdAt: Date

    var thumbnailURL: URL? { imageURLs.last }
}
