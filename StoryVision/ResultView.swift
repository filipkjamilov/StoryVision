import SwiftUI

#if canImport(UIKit)
struct ResultView: View {
    let image: UIImage
    let prompt: String

    @State private var savedToPhotos = false
    @State private var showShareSheet = false
    @State private var uploadState: UploadState = .uploading

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                uploadBanner

                actionBar
            }
        }
        .navigationTitle("Your Vision")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [image])
        }
        .task { await uploadToFirebase() }
    }

    @ViewBuilder
    private var uploadBanner: some View {
        switch uploadState {
        case .uploading:
            HStack(spacing: 8) {
                ProgressView().tint(.white).scaleEffect(0.8)
                Text("Saving to your stories…")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 12)
        case .done:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: "22C55E"))
                Text("Saved to your stories")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 12)
        case .failed:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color(hex: "F87171"))
                Text("Could not save to stories")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 12)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                withAnimation { savedToPhotos = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { savedToPhotos = false }
                }
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

    private func uploadToFirebase() async {
        do {
            _ = try await StorageService.uploadImage(
                image: image,
                storyID: UUID().uuidString,
                prompt: prompt,
                storyCreatedAt: Date(),
                index: 0
            )
            withAnimation { uploadState = .done }
        } catch {
            withAnimation { uploadState = .failed }
        }
    }
}

private enum UploadState { case uploading, done, failed }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ResultView(image: UIImage(systemName: "photo")!, prompt: "A bear meets two travellers.")
    }
}
#endif
