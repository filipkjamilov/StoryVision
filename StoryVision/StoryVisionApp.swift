import SwiftUI
import FirebaseCore
import RevenueCat

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
        return true
    }
}

@main
struct StoryVisionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var subscriptions = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptions)
                .task {
                    subscriptions.start()
                }
        }
    }
}
