import GoogleMobileAds
import SwiftUI
import UIKit

@MainActor
final class NativeAdManager: NSObject {
    
    static let shared = NativeAdManager()
    
    private var completionHandlers: [AdLoader: (NativeAd?) -> Void] = [:]
    
    private var lastNativeAdErrorTime: Date?
    private let nativeAdRetryCooldown: TimeInterval = 90 // seconds (optimized for native ads stability & eCPM)

    // MARK: - Preloaded Native Ads
    private var preloadedNativeAds: [NativeAd] = []

    /// Number of ads currently being requested for the preload cache.
    private var preloadingNativeAdsCount = 0

    private override init() {
        super.init()
    }
    
    func resetErrorCounter() {
        AdsConfig.currentNativeAdErrorCount = 0
        lastNativeAdErrorTime = nil
    }
    
    private func incrementErrorCounter() {
        AdsConfig.currentNativeAdErrorCount += 1
        lastNativeAdErrorTime = Date()
    }
    
    private func hasExceededErrorLimit() -> Bool {
        if AdsConfig.currentNativeAdErrorCount < AdsConfig.nativeAdErrorCount {
            return false
        }

        guard let lastErrorTime = lastNativeAdErrorTime else {
            return true
        }

        let canRetry = Date().timeIntervalSince(lastErrorTime) >= nativeAdRetryCooldown
        if canRetry {
            resetErrorCounter()
            lastNativeAdErrorTime = nil
        }

        return !canRetry
    }

    // MARK: - Preload Native Ads

    public func preloadNativeAds(
        rootViewController: UIViewController,
        count: Int = 1
    ) async {
        guard AdsConfig.nativeAdEnabled && AdsConfig.nativeAdPreloadEnabled else {
            return
        }

        // Calculate how many ads are still required,
        // including requests that are already in progress.
        let availableSlots =
        AdsConfig.nativeAdPreloadCount
        - preloadedNativeAds.count
        - preloadingNativeAdsCount

        let requiredCount = min(count, max(availableSlots, 0))

        guard requiredCount > 0 else {
            return
        }

        // Reserve the slots before starting network requests.
        preloadingNativeAdsCount += requiredCount

        for _ in 0..<requiredCount {
            let nativeAd = await requestNativeAd(
                rootViewController: rootViewController
            )

            // Request has finished.
            preloadingNativeAdsCount -= 1

            guard let nativeAd else {
                continue
            }

            // Make sure the cache never exceeds the maximum.
            guard preloadedNativeAds.count < AdsConfig.nativeAdPreloadCount else {
                continue
            }

            preloadedNativeAds.append(nativeAd)
        }
    }
    
    // MARK: - Get Preloaded Native Ad
    private func getPreloadedNativeAd() -> NativeAd? {
        guard !preloadedNativeAds.isEmpty else {
            return nil
        }

        return preloadedNativeAds.removeFirst()
    }
    
    // MARK: - Native Ad Loading
    public func loadNativeAd(
        in containerView: UIView,
        viewController: UIViewController,
        adView: NativeAdView,
        height: CGFloat,
        completion: @escaping (Bool, CGFloat) -> Void
    ) {
        let shimmerView = AdShimmerView()
        shimmerView.show(
            in: containerView,
            height: height
        )

        Task { @MainActor [weak self] in
            guard let self else {
                shimmerView.remove()
                completion(false, 0)
                return
            }

            // 1. Try preloaded ad first
            if let preloadedAd = self.getPreloadedNativeAd() {

                shimmerView.remove()

                self.renderNativeAd(
                    in: containerView,
                    adView: adView,
                    nativeAd: preloadedAd
                )

                completion(true, height)

                // Refill preload cache
                await self.preloadNativeAds(
                    rootViewController: viewController,
                    count: 1
                )

                return
            }

            // 2. No preloaded ad → request from network
            let nativeAd = await self.requestNativeAd(
                rootViewController: viewController
            )

            shimmerView.remove()

            guard let nativeAd else {
                completion(false, 0)
                return
            }

            self.renderNativeAd(
                in: containerView,
                adView: adView,
                nativeAd: nativeAd
            )

            completion(true, height)

            // 3. Refill preload cache
            await self.preloadNativeAds(
                rootViewController: viewController,
                count: 1
            )
        }
    }
    
    // MARK: - Request Native Ad
    private func requestNativeAd(
        rootViewController: UIViewController?
    ) async -> NativeAd? {
        
        guard AdsConfig.nativeAdEnabled else {
            return nil
        }

        guard !hasExceededErrorLimit() else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            
            let adLoader = AdLoader(
                adUnitID: AdsConfig.nativeAdUnitId,
                rootViewController: rootViewController,
                adTypes: [.native],
                options: nil
            )

            completionHandlers[adLoader] = { nativeAd in
                continuation.resume(returning: nativeAd)
            }

            adLoader.delegate = self
            adLoader.load(Request())
        }
    }
    
    // MARK: - Native Ad Rendering
    private func renderNativeAd(
        in containerView: UIView,
        adView: NativeAdView,
        nativeAd: NativeAd
    ) {
        // Remove any existing native ad views to prevent stacking
        containerView.subviews.forEach { $0.removeFromSuperview() }
        
        containerView.clipsToBounds = true
        adView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(adView)
        
        NSLayoutConstraint.activate([
            adView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            adView.topAnchor.constraint(equalTo: containerView.topAnchor),
            adView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Assign the nativeAd to GADNativeAdView
        adView.nativeAd = nativeAd
        
        adView.mediaView?.contentMode = .scaleAspectFill
        adView.mediaView?.clipsToBounds = true
        adView.mediaView?.mediaContent = nativeAd.mediaContent
        
        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        
        // Optional extra assets
        (adView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        (adView.priceView as? UILabel)?.text = nativeAd.price
        (adView.storeView as? UILabel)?.text = nativeAd.store
        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        
        // Set the star rating
        if let starRating = nativeAd.starRating {
            (adView.starRatingView as? UIImageView)?.image = getStarRatingImage(for: starRating)
            adView.starRatingView?.isHidden = false
        } else {
            adView.starRatingView?.isHidden = true // Hide if no rating
        }
        
        adView.callToActionView?.isUserInteractionEnabled = false // Required
    }
    
}

// MARK: - SwiftUI Native Wrapper
public struct NativeAdContainerView: UIViewRepresentable {
    
    public let adView: NativeAdView
    public let height: CGFloat
    
    @Binding private var isLoaded: Bool
    @Binding private var resolvedHeight: CGFloat
    
    public init(
        adView: NativeAdView,
        height: CGFloat,
        isLoaded: Binding<Bool> = .constant(false),
        resolvedHeight: Binding<CGFloat> = .constant(0)
    ) {
        self.adView = adView
        self.height = height
        self._isLoaded = isLoaded
        self._resolvedHeight = resolvedHeight
    }
    
    public func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.clipsToBounds = true
        containerView.frame.size.height = height
        
        guard let rootVC = UIApplication.shared.adsManagerRootViewController else {
            isLoaded = false
            resolvedHeight = 0
            return containerView
        }
        
        NativeAdManager.shared.loadNativeAd(
            in: containerView,
            viewController: rootVC,
            adView: adView,
            height: height
        ) { loaded, resolvedAdHeight in
            isLoaded = loaded
            resolvedHeight = resolvedAdHeight
            containerView.frame.size.height = resolvedAdHeight
        }
        
        return containerView
    }
    
    public func updateUIView(
        _ uiView: UIView,
        context: Context
    ) {
    }
}

private extension UIApplication {
    var adsManagerRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }
}

func getStarRatingImage(for rating: NSDecimalNumber) -> UIImage? {
    let ratingValue = rating.floatValue
    let fullStars = Int(ratingValue)
    let hasHalfStar = ratingValue - Float(fullStars) >= 0.5

    var starImages: [UIImage] = []

    let filledColor = UIColor.systemYellow
    let emptyColor = UIColor.systemGray3
    let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)

    func star(_ name: String, color: UIColor) -> UIImage? {
        UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }

    // Full stars
    for _ in 0..<fullStars {
        if let img = star("star.fill", color: filledColor) {
            starImages.append(img)
        }
    }

    // Half star
    if hasHalfStar {
        if let img = star("star.leadinghalf.filled", color: filledColor) {
            starImages.append(img)
        }
    }

    // Empty stars
    let emptyCount = 5 - fullStars - (hasHalfStar ? 1 : 0)
    for _ in 0..<emptyCount {
        if let img = star("star", color: emptyColor) {
            starImages.append(img)
        }
    }

    return combineStarImages(starImages)
}

func combineStarImages(_ images: [UIImage]) -> UIImage? {
    // Calculate combined width based on the number of stars
    let starWidth: CGFloat = 20
    let starHeight: CGFloat = 20
    let combinedWidth = CGFloat(images.count) * starWidth
    
    // Use scale = 0.0 to match device pixel density (avoids blurriness)
    UIGraphicsBeginImageContextWithOptions(CGSize(width: combinedWidth, height: starHeight), false, 0.0)
    
    for (index, image) in images.enumerated() {
        image.draw(in: CGRect(x: CGFloat(index) * starWidth, y: 0, width: starWidth, height: starHeight))
    }
    
    let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return combinedImage
}

// MARK: - GADNativeAdLoaderDelegate
extension NativeAdManager: NativeAdLoaderDelegate {
    nonisolated public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        Task { @MainActor in
            self.handleAdLoaded(adLoader: adLoader, nativeAd: nativeAd)
        }
    }

    nonisolated public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            self.handleAdFailed(adLoader: adLoader, error: error)
        }
    }
}

@MainActor
private extension NativeAdManager {
    func handleAdLoaded(adLoader: AdLoader, nativeAd: NativeAd) {
        resetErrorCounter()
        if let completion = completionHandlers[adLoader] {
            completion(nativeAd)
            completionHandlers.removeValue(forKey: adLoader)
        }
    }

    func handleAdFailed(adLoader: AdLoader, error: Error) {
        incrementErrorCounter()
        if let completion = completionHandlers[adLoader] {
            completion(nil)
            completionHandlers.removeValue(forKey: adLoader)
        }
    }
}

// MARK: - Sendable Conformance for SDK Types
extension NativeAd: @unchecked @retroactive Sendable {}
extension AdLoader: @unchecked @retroactive Sendable {}
