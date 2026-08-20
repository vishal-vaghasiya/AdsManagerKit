import GoogleMobileAds
import SwiftUI
import UIKit

public enum BannerAdType: String, CaseIterable, Hashable, Sendable {
    case regular
    case large
    case largeAdaptive
}

@MainActor
final class BannerAdManager: NSObject {
    
    static let shared = BannerAdManager()
    
    private var bannerView: BannerView?
    private var completionHandler: ((Bool, CGFloat) -> Void)?
    private(set) var bannerHeight: CGFloat = 0
    
    private var lastBannerAdErrorTime: Date?
    private let bannerAdRetryCooldown: TimeInterval = 60

    public func resetErrorCounter() {
        AdsConfig.currentBannerAdErrorCount = 0
        lastBannerAdErrorTime = nil
    }
    
    private func incrementErrorCounter() {
        AdsConfig.currentBannerAdErrorCount += 1
        lastBannerAdErrorTime = Date()
    }
    
    private func hasExceededErrorLimit() -> Bool {
        if AdsConfig.currentBannerAdErrorCount < AdsConfig.bannerAdErrorCount {
            return false
        }

        guard let lastErrorTime = lastBannerAdErrorTime else {
            return true
        }

        let canRetry = Date().timeIntervalSince(lastErrorTime) >= bannerAdRetryCooldown
        if canRetry {
            resetErrorCounter()
        }

        return !canRetry
    }
    
    func loadBannerAd(
        in containerView: UIView,
        vc: UIViewController,
        type: BannerAdType,
        completion: @escaping (Bool, CGFloat) -> Void
    ) {
        guard AdsConfig.bannerAdEnabled else {
            completion(false, 0)
            return
        }

        guard !hasExceededErrorLimit() else {
            #if DEBUG
            print("[BannerAd] ⚠️ Max retries exceeded — not loading or showing.")
            #endif
            completion(false, 0)
            return
        }

        containerView.layoutIfNeeded()

        let viewWidth = containerView.bounds.width

        guard viewWidth > 0 else {
            completion(false, 0)
            return
        }

        let adSize: AdSize

        switch type {
        case .regular:
            adSize = AdSizeBanner

        case .large:
            adSize = AdSizeLargeBanner

        case .largeAdaptive:
            adSize = largeAnchoredAdaptiveBanner(width: viewWidth)
        }

        bannerHeight = adSize.size.height

        // Show shimmer while banner is loading
        let shimmerView = AdShimmerView()
        shimmerView.show(
            in: containerView,
            height: bannerHeight
        )

        // Remove previous banner
        removeCurrentBanner()

        // Store completion and remove shimmer when loading finishes
        self.completionHandler = { success, height in
            shimmerView.remove()
            completion(success, height)
        }

        let banner = BannerView(adSize: adSize)
        bannerView = banner

        banner.adUnitID = AdsConfig.bannerAdUnitId
        banner.rootViewController = vc
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(banner)
        containerView.clipsToBounds = true

        NSLayoutConstraint.activate([
            banner.bottomAnchor.constraint(
                equalTo: containerView.safeAreaLayoutGuide.bottomAnchor
            ),
            banner.centerXAnchor.constraint(
                equalTo: containerView.centerXAnchor
            )
        ])

        banner.load(Request())
    }
    
    private func removeCurrentBanner() {
        guard let banner = bannerView else {
            return
        }

        banner.delegate = nil
        banner.removeFromSuperview()
        bannerView = nil
    }

    // MARK: - SwiftUI Banner Container
    public func makeBannerContainer(adType: BannerAdType,
                                    onAdLoaded: ((CGFloat) -> Void)? = nil,
                                    onAdStateChanged: ((Bool, CGFloat) -> Void)? = nil) -> UIView {
        let containerView = UIView()
        
        guard let rootVC = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
                return containerView
            }
        
        // Load the banner and forward its state to SwiftUI.
        loadBannerAd(in: containerView, vc: rootVC, type: adType) { success, height in
            let resolvedHeight = success ? height : 0
            onAdStateChanged?(success, resolvedHeight)
            if success {
                onAdLoaded?(resolvedHeight)
            }
        }
        
        return containerView
    }
}

extension BannerAdManager: BannerViewDelegate {
    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        #if DEBUG
        print("[BannerAd] loaded.")
        #endif

        resetErrorCounter()

        completionHandler?(true, bannerHeight)
        completionHandler = nil
    }
    
    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        #if DEBUG
        print("[BannerAd] Failed to load: \(error.localizedDescription)")
        #endif
        
        incrementErrorCounter()
        
        completionHandler?(false, 0)
        completionHandler = nil
    }
}

// MARK: - SwiftUI Banner Wrapper
public struct BannerAdView: UIViewRepresentable {
    public var adType: BannerAdType
    public var onAdLoaded: ((CGFloat) -> Void)? = nil
    @Binding private var isLoaded: Bool
    @Binding private var height: CGFloat

    public init(adType: BannerAdType,
                isLoaded: Binding<Bool> = .constant(false),
                height: Binding<CGFloat> = .constant(0),
                onAdLoaded: ((CGFloat) -> Void)? = nil) {
        self.adType = adType
        self._isLoaded = isLoaded
        self._height = height
        self.onAdLoaded = onAdLoaded
    }

    public func makeUIView(context: Context) -> UIView {
        BannerAdManager.shared.makeBannerContainer(
            adType: adType,
            onAdLoaded: onAdLoaded,
            onAdStateChanged: { loaded, resolvedHeight in
                DispatchQueue.main.async {
                    isLoaded = loaded
                    height = resolvedHeight
                }
            }
        )
    }

    public func updateUIView(_ uiView: UIView, context: Context) { }
}
