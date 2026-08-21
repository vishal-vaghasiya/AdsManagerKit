import SwiftUI
import AdsManagerKit

struct SplashContentView: View {
    @State private var adDelegate = SplashAdDelegate()
    @State private var showMainScreen = false

    var body: some View {
        Group {
            if showMainScreen {
                MenuView()
            } else {
                Text("Welcome to AdsManagerKit")
            }
        }
        .onAppear {
            configureAds()
        }
    }

    private func configureAds() {
        #if DEBUG
        let isProduction = false
        #else
        let isProduction = true
        #endif

        AdsManager.configureAds(
            isProduction: isProduction,
            openAdEnabled: true,
            openAdOnSplashEnabled: true,
            bannerAdEnabled: true,
            interstitialAdEnabled: true,
            nativeAdEnabled: true,
            nativeAdPreloadEnabled: true,
            nativeAdPreloadCount: 1
        )

        adDelegate.onComplete = {
            startMainScreen()
        }

        AdsManager.configure {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                AdsManager.shared.tryToPresentSplashAd(
                    delegate: adDelegate
                )
            }
        }
    }

    @MainActor
    private func startMainScreen() {
        showMainScreen = true
    }
}

#Preview {
    SplashContentView()
}
