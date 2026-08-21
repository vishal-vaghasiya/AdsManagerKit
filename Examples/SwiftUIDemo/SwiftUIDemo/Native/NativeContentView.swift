import AdsManagerKit
import SwiftUI
import GoogleMobileAds
struct NativeContentView: View {
    @State private var nativeIsLoaded = false
    @State private var nativeHeight: CGFloat = 350
    private let nativeAdView: NativeAdView = {
        let bundle = Bundle(for: NativeAdView.self)
        guard let adView = bundle.loadNibNamed("NativeAdView", owner: nil, options: nil)?.first as? NativeAdView else {
            fatalError("Could not load NativeAdView.xib")
        }
        return adView
    }()
    
    var body: some View {
        VStack {
            Spacer()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NativeAdContainerView(
                adView: nativeAdView,
                height: nativeHeight,
                isLoaded: $nativeIsLoaded,
                resolvedHeight: $nativeHeight
            )
            .frame(height: nativeHeight > 0 ? nativeHeight : 0)
        }
    }
}

#Preview {
    NativeContentView()
}
