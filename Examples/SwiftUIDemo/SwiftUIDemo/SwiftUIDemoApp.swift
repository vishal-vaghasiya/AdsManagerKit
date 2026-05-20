//
//  SwiftUIDemoApp.swift
//  SwiftUIDemo
//
//

import AdsManagerKit
import SwiftUI

@main
struct SwiftUIDemoApp: App {
    init() {
        AdsManager.configureAds(
            isProduction: false,
            openAdEnabled: false,
            bannerAdEnabled: true,
            interstitialAdEnabled: false,
            nativeAdEnabled: true
        )
        AdsManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
