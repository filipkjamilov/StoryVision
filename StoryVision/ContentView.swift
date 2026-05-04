import SwiftUI

struct ContentView: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var showSubscriptions = false

    var body: some View {
#if os(iOS)
        NavigationStack {
            RecordView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSubscriptions = true
                        } label: {
                            Image(systemName: subscriptions.hasProAccess ? "crown.fill" : "crown")
                        }
                        .accessibilityLabel("StoryVision Pro")
                    }
                }
        }
        .sheet(isPresented: $showSubscriptions) {
            SubscriptionStoreView()
        }
#else
        Text("StoryVision is only available on iOS.")
            .padding()
#endif
    }
}

#Preview {
    ContentView()
        .environment(SubscriptionManager())
}
