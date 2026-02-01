import GoogleMobileAds
import UIKit
public enum AdType: String {
    case SMALL = "NativeAdView_Small"   //108
    case MEDIUM = "NativeAdView_Medium" //170
    case LARGE = "NativeAdView"         //280
}
@MainActor
final class NativeAdManager: NSObject {
    
    static let shared = NativeAdManager()
    
    private var completionHandlers: [AdLoader: (NativeAd?) -> Void] = [:]
    
    private var lastNativeAdErrorTime: Date?
    private let nativeAdRetryCooldown: TimeInterval = 90 // seconds (optimized for native ads stability & eCPM)

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
    
    private func createAdRequest() -> Request {
        return Request() // Latest UMP SDK automatically handles ATT/GDPR
    }
    
    // MARK: - Get Ad (Always Load On Demand)
    func getAd(in containerView: UIView, viewController: UIViewController, adType: AdType, completion: @escaping (Bool) -> Void) {
        loadAd(rootViewController: viewController) { [weak self] ad in
            guard let self else { return }
            if let ad {
                self.displayNativeAd(in: containerView, ad, adType: adType)
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    // MARK: - Internal Ad Loader
    private func loadAd(rootViewController: UIViewController?, completion: @escaping (NativeAd?) -> Void) {
        guard AdsConfig.nativeAdEnabled else {
            completion(nil)
            return
        }
        
        guard !hasExceededErrorLimit() else {
            completion(nil)
            return
        }
        
        let adLoader = AdLoader(
            adUnitID: AdsConfig.nativeAdUnitId,
            rootViewController: rootViewController,
            adTypes: [.native],
            options: nil
        )
        
        completionHandlers[adLoader] = completion
        adLoader.delegate = self
        adLoader.load(createAdRequest())
    }
    
    /// Displays a Google Mobile Ads native ad inside the specified container view.
    /// - Parameters:
    ///   - containerView: The UIView where the native ad will be rendered.
    ///   - nativeAd: The loaded `NativeAd` instance to be displayed.
    ///   - adType: The `AdType` defining which ad layout (Small, Medium, or Large) XIB to load.
    ///
    /// Loads the appropriate XIB for the given `adType`, binds ad assets (headline, icon, CTA, etc.)
    /// to the UI elements, and adds it to the container view. Also ensures interaction behavior and
    /// star rating display are configured correctly.
    private func displayNativeAd(in containerView: UIView, _ nativeAd: NativeAd, adType: AdType) {
        // Remove any existing native ad views to prevent stacking
        //containerView.subviews.forEach { $0.removeFromSuperview() }
        
        // Load the custom XIB
        guard let adView = Bundle.module.loadNibNamed(adType.rawValue, owner: nil, options: nil)?.first as? NativeAdView else {
            return
        }
        
        // Set frame to match container
        adView.frame = containerView.bounds
        containerView.addSubview(adView)
        
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
