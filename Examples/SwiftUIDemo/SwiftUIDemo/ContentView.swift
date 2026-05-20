//
//  ContentView.swift
//  SwiftUIDemo
//
//

import AdsManagerKit
import SwiftUI

struct ContentView: View {
    @State private var bannerIsLoaded = false
    @State private var bannerHeight: CGFloat = 0

    @State private var nativeIsLoaded = false
    @State private var nativeHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 20) {
            NativeAdContainerView(
                adType: .MEDIUM,
                isLoaded: $nativeIsLoaded,
                height: $nativeHeight
            )
            .frame(height: nativeHeight)
            .opacity(nativeIsLoaded ? 1 : 0)

            BannerAdView(
                adType: .ADAPTIVE,
                isLoaded: $bannerIsLoaded,
                height: $bannerHeight
            )
            .frame(height: bannerHeight)
            .opacity(bannerIsLoaded ? 1 : 0)
        }
    }
}

#Preview {
    ContentView()
}
