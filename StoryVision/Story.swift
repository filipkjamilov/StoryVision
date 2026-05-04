import Foundation

struct Story: Identifiable {
    let id: String
    let prompt: String
    let imageURL: URL
    let audioURL: URL?
    let createdAt: Date
}
