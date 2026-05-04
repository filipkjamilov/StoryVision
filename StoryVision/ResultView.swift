import SwiftUI

#if canImport(UIKit)
struct ResultView: View {
    let image: UIImage
    @State private var showShareSheet = false
    @State private var savedToPhotos = false

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

                actionBar
            }
        }
        .navigationTitle("Your Vision")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [image])
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

            Button {
                showShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient.storyPurple)
                    )
                    .shadow(color: Color(hex: "7C3AED").opacity(0.4), radius: 10)
            }
        }
        .padding(24)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ResultView(image: UIImage(systemName: "photo")!)
    }
}
#endif
