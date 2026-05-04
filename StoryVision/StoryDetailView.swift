import SwiftUI

#if os(iOS)
struct StoryDetailView: View {
    let story: Story
    @State private var savedToPhotos = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                AsyncImage(url: story.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        Color.white.opacity(0.05)
                            .overlay(Image(systemName: "exclamationmark.triangle").foregroundStyle(.white))
                    default:
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text(story.prompt)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(4)

                    Text(story.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                HStack(spacing: 12) {
                    Button {
                        Task { await saveToPhotos() }
                    } label: {
                        Label(savedToPhotos ? "Saved!" : "Save", systemImage: savedToPhotos ? "checkmark" : "square.and.arrow.down")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(savedToPhotos ? Color(hex: "22C55E").opacity(0.8) : Color.white.opacity(0.12))
                            )
                    }
                    .animation(.spring(duration: 0.3), value: savedToPhotos)

                    Button { showShareSheet = true } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient.storyPurple))
                            .shadow(color: Color(hex: "7C3AED").opacity(0.4), radius: 10)
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [story.imageURL])
        }
    }

    private func saveToPhotos() async {
        guard let (data, _) = try? await URLSession.shared.data(from: story.imageURL),
              let image = UIImage(data: data) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation { savedToPhotos = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { savedToPhotos = false }
        }
    }
}

#Preview {
    StoryDetailView(story: Story(
        id: "1",
        prompt: "A bear meets two travellers on a forest road.",
        imageURL: URL(string: "https://picsum.photos/400")!,
        createdAt: Date()
    ))
}
#endif
