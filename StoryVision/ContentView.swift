import SwiftUI

struct ContentView: View {
    var body: some View {
#if os(iOS)
        NavigationStack {
            RecordView()
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
