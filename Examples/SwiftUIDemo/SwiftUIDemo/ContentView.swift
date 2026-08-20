//
//  ContentView.swift
//  SwiftUIDemo
//
//

import AdsManagerKit
import SwiftUI
import GoogleMobileAds
struct ContentView: View {
    @State private var bannerIsLoaded = false
    @State private var bannerHeight: CGFloat = 0

    @State private var nativeIsLoaded = false
    @State private var nativeHeight: CGFloat = 300
    private let nativeAdView: NativeAdView = {
        let bundle = Bundle(for: NativeAdView.self)
        guard let adView = bundle.loadNibNamed("NativeAdView", owner: nil, options: nil)?.first as? NativeAdView else {
            fatalError("Could not load NativeAdView.xib")
        }
        return adView
    }()
    
    var body: some View {
        VStack {
            Button("Show Interstitial") {
                AdsManager.shared.showInterstitialIfAvailable()
            }
            Spacer()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            /*BannerAdView(
                adType: .regular,
                isLoaded: $bannerIsLoaded,
                height: $bannerHeight
            )
            .frame(height: bannerHeight)
            .opacity(bannerIsLoaded ? 1 : 0)*/
            
            /*NativeAdContainerView(
                adView: nativeAdView,
                height: nativeHeight,
                isLoaded: $nativeIsLoaded,
                resolvedHeight: $nativeHeight
            )
            .frame(height: nativeHeight)
            .opacity(nativeIsLoaded ? 1 : 0)*/
        }
    }
}

#Preview {
    ContentView()
}
