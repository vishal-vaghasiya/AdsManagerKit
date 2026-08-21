import SwiftUI
import GoogleMobileAds

public struct InlineBannerAdView: UIViewRepresentable {

    public let adIndex: Int
    public var bannerView: BannerView?

    @Binding private var isLoaded: Bool
    @Binding private var height: CGFloat

    public var onAdLoaded: ((CGFloat) -> Void)?
    public var onAdFailed: ((Error) -> Void)?

    public init(
        adIndex: Int = 0,
        bannerView: BannerView? = nil,
        isLoaded: Binding<Bool> = .constant(false),
        height: Binding<CGFloat> = .constant(0),
        onAdLoaded: ((CGFloat) -> Void)? = nil,
        onAdFailed: ((Error) -> Void)? = nil
    ) {
        self.adIndex = adIndex
        self.bannerView = bannerView
        self._isLoaded = isLoaded
        self._height = height
        self.onAdLoaded = onAdLoaded
        self.onAdFailed = onAdFailed
    }

    public func makeUIView(context: Context) -> InlineBannerContainerView {
        let containerView = InlineBannerContainerView()

        containerView.backgroundColor = .clear
        containerView.adIndex = adIndex

        containerView.onAdLoaded = { loadedHeight in
            DispatchQueue.main.async {
                self.isLoaded = true
                self.height = loadedHeight
                self.onAdLoaded?(loadedHeight)
            }
        }

        containerView.onAdFailed = { error in
            DispatchQueue.main.async {
                self.isLoaded = false
                self.height = 0
                self.onAdFailed?(error)
            }
        }

        if let bannerView = bannerView {
            containerView.setBannerView(bannerView)
        }

        return containerView
    }

    public func updateUIView(
        _ uiView: InlineBannerContainerView,
        context: Context
    ) {
        uiView.adIndex = adIndex

        uiView.onAdLoaded = { loadedHeight in
            DispatchQueue.main.async {
                self.isLoaded = true
                self.height = loadedHeight
                self.onAdLoaded?(loadedHeight)
            }
        }

        uiView.onAdFailed = { error in
            DispatchQueue.main.async {
                self.isLoaded = false
                self.height = 0
                self.onAdFailed?(error)
            }
        }

        if let bannerView = bannerView {
            uiView.setBannerView(bannerView)
        } else {
            uiView.loadAdIfNeeded()
        }
    }
}
