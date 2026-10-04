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
            configureSetup()
        }
    }
    
    private func configureSetup() {
        let configuration = AppConfigurationLoader.load()
        
        adDelegate.onComplete = {
            startMainScreen()
        }
        
        AdsManager.initialize(with: configuration) {
            DispatchQueue.main.asyncAfter(deadline: .now() + AdsConfig.splashDelaySeconds, execute: {
                AdsManager.shared.tryToPresentSplashAd(
                    delegate: adDelegate
                )
            })
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
