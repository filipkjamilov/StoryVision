import SwiftUI

#if os(iOS)
struct StoriesView: View {
    @State private var stories: [Story] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedStory: Story?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            LinearGradient.appBackground.ignoresSafeArea()

            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.4)
                } else if stories.isEmpty {
                    emptyState
                } else {
                    storiesGrid
                }
            }

            if let errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.red.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding()
                }
            }
        }
        .navigationTitle("My Stories")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadStories() }
        .sheet(item: $selectedStory) { story in
            StoryDetailView(story: story)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.3))
            Text("No stories yet")
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.5))
            Text("Generate an image from your first story!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
    }

    private var storiesGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(stories) { story in
                    StoryThumbnail(story: story)
                        .onTapGesture { selectedStory = story }
                }
            }
            .padding(16)
        }
    }

    private func loadStories() async {
        isLoading = true
        do {
            stories = try await StorageService.fetchAllStories()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct StoryThumbnail: View {
    let story: Story

    var body: some View {
        AsyncImage(url: story.thumbnailURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                Color.white.opacity(0.05)
                    .overlay(Image(systemName: "exclamationmark.triangle").foregroundStyle(.white.opacity(0.3)))
            default:
                Color.white.opacity(0.05)
                    .overlay(ProgressView().tint(.white))
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            VStack {
                Spacer()
                Text(story.prompt)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack { StoriesView() }
}
#endif
