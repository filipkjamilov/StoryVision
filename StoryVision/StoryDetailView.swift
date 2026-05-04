import SwiftUI

#if os(iOS)
struct StoryDetailView: View {
    let story: Story
    @State private var selectedIndex = 0
    @State private var savedToPhotos = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    private var currentURL: URL? { story.imageURLs[safe: selectedIndex] }

    var body: some View {
        ZStack {
            LinearGradient.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                imageCarousel
                    .padding(.top, 16)

                if story.imageURLs.count > 1 {
                    Text("Scene \(selectedIndex + 1) of \(story.imageURLs.count)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 6)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Your Story")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LinearGradient.storyPurple)
                            .textCase(.uppercase)
                            .tracking(1)

                        Spacer()

                        Text(story.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.35))
                    }

                    Text(story.prompt)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer()

                actionBar
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = currentURL { ShareSheet(items: [url]) }
        }
    }

    // MARK: - Image carousel

    private var imageCarousel: some View {
        GeometryReader { geo in
            let imageHeight = (geo.size.width - 32) * 9.0 / 16.0
            TabView(selection: $selectedIndex) {
                ForEach(Array(story.imageURLs.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        case .failure:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.white.opacity(0.3))
                                )
                        default:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(ProgressView().tint(.white))
                        }
                    }
                    .frame(height: imageHeight)
                    .padding(.horizontal, 16)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: story.imageURLs.count > 1 ? .always : .never))
            .frame(height: imageHeight + 28) // +28 for page dots
        }
        .frame(height: (UIScreen.main.bounds.width - 32) * 9.0 / 16.0 + 28)
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await saveCurrentImage() }
            } label: {
                Label(
                    savedToPhotos ? "Saved!" : "Save",
                    systemImage: savedToPhotos ? "checkmark" : "square.and.arrow.down"
                )
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

    private func saveCurrentImage() async {
        guard let url = currentURL,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation { savedToPhotos = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { savedToPhotos = false }
        }
    }
}

// Safe subscript to avoid index-out-of-bounds on URL arrays
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    StoryDetailView(story: Story(
        id: "1",
        prompt: "A bear meets two travellers on a forest road.",
        imageURLs: [
            URL(string: "https://picsum.photos/seed/a/800/450")!,
            URL(string: "https://picsum.photos/seed/b/800/450")!,
            URL(string: "https://picsum.photos/seed/c/800/450")!
        ],
        createdAt: Date()
    ))
}
#endif
