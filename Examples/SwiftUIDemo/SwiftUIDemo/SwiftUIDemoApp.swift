import AdsManagerKit
import SwiftUI

@main
struct SwiftUIDemoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var wasInBackground = false
    
    init() {
        AdsManager.configureAds(
            isProduction: false,
            openAdEnabled: true,
            openAdOnSplashEnabled: true,
            bannerAdEnabled: true,
            interstitialAdEnabled: true,
            nativeAdEnabled: true,
            nativeAdPreloadEnabled: true,
            nativeAdPreloadCount: 1
        )
        AdsManager.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                wasInBackground = true
            case .active:
                guard wasInBackground else { return }
                wasInBackground = false
                AdsManager.shared.showAppOpenAdIfAvailable()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
