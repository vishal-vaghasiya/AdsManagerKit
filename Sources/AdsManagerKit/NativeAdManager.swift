import GoogleMobileAds
import UIKit
public enum AdType: String {
    case SMALL = "NativeAdView_Small"//120
    case MEDIUM = "NativeAdView_Medium"
    case LARGE = "NativeAdView"
}
@MainActor
final class NativeAdManager: NSObject {
    
    static let shared = NativeAdManager()
    
    // For handling individual ad requests
    private var completionHandlers: [AdLoader: (NativeAd?) -> Void] = [:]
    private var adCache: [NativeAd] = []
    private let maxCacheCapacity = 3
    private var activeAdLoaders: [AdLoader] = []
    private var completionHandler: ((Bool) -> Void)?
    
    private override init() {
        super.init()
    }
    
    func resetErrorCounter() {
        AdsConfig.currentNativeAdErrorCount = 0
    }
    
    private func incrementErrorCounter() {
        AdsConfig.currentNativeAdErrorCount += 1
    }
    
    private func hasExceededErrorLimit() -> Bool {
        return AdsConfig.currentNativeAdErrorCount >= AdsConfig.nativeAdErrorCount
    }
    
    private func createAdRequest() -> Request {
        return Request() // Latest UMP SDK automatically handles ATT/GDPR
    }
    
    // MARK: - Preload Native Ads
    func preloadNativeAds(count: Int = 1) {
        if AdsConfig.nativeAdPreloadEnabled {
            for i in 0..<count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                    self.loadAd()
                }
            }
        }
    }
    
    // MARK: - Get Ad (Cached or Load On Demand)
    func getAd(in containerView: UIView,
               adType: AdType,
               completion: @escaping (Bool) -> Void) {
        self.completionHandler = completion
        if let ad = adCache.first {
            adCache.removeFirst()
            self.displayNativeAd(in: containerView, ad, adType: adType)
            // Start preloading again to maintain cache size
            loadAd()
        } else {
            // No cached ad → Load now
            loadAd { ad in
                if ad != nil {
                    self.displayNativeAd(in: containerView, ad!, adType: adType)
                } else {
                    self.completionHandler?(false)
                }
            }
        }
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
        // Load the custom XIB
        guard let adView = Bundle.module.loadNibNamed(adType.rawValue, owner: nil, options: nil)?.first as? NativeAdView else {
            self.completionHandler?(false)
            return
        }
        
        // Set frame to match container
        adView.frame = containerView.bounds
        containerView.addSubview(adView)
        
        // Assign the nativeAd to GADNativeAdView
        adView.nativeAd = nativeAd
        
        // Bind assets
        if adType == .SMALL {
            (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
            (adView.headlineView as? UILabel)?.text = nativeAd.headline
            (adView.storeView as? UILabel)?.text = nativeAd.store
            (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
            if let starRating = nativeAd.starRating {
                (adView.starRatingView as? UIImageView)?.image = getStarRatingImage(for: starRating)
                adView.starRatingView?.isHidden = false
            } else {
                adView.starRatingView?.isHidden = true // Hide if no rating
            }
        }
        
        if adType == .MEDIUM {
            adView.mediaView?.mediaContent = nativeAd.mediaContent
            (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
            (adView.headlineView as? UILabel)?.text = nativeAd.headline
            (adView.advertiserView as? UILabel)?.text = nativeAd.advertiser
            (adView.storeView as? UILabel)?.text = nativeAd.store
            (adView.bodyView as? UILabel)?.text = nativeAd.body
            (adView.priceView as? UILabel)?.text = nativeAd.price
            (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
            if let starRating = nativeAd.starRating {
                (adView.starRatingView as? UIImageView)?.image = getStarRatingImage(for: starRating)
                adView.starRatingView?.isHidden = false
            } else {
                adView.starRatingView?.isHidden = true // Hide if no rating
            }
        }
        
        if adType == .LARGE {
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
        }
        adView.callToActionView?.isUserInteractionEnabled = false // Required
    }
    
    // MARK: - Internal Ad Loader
    private func loadAd(completion: ((NativeAd?) -> Void)? = nil) {
        if !AdsConfig.nativeAdEnabled {
            self.completionHandler?(false)
            return
        }
        guard !hasExceededErrorLimit() else {
            #if DEBUG
            print("[NativeAd] ⚠️ Max error attempts reached — not loading.")
            #endif
            self.completionHandler?(false)
            return
        }
        
        let adLoader = AdLoader(adUnitID: AdsConfig.nativeAdUnitId,
                                rootViewController: nil,
                                adTypes: [.native],
                                options: nil)
        if let completion = completion {
            completionHandlers[adLoader] = completion
        }
        adLoader.delegate = self
        activeAdLoaders.append(adLoader)
        adLoader.load(createAdRequest())
    }
    
}

func getStarRatingImage(for rating: NSDecimalNumber) -> UIImage? {
    let ratingValue = rating.floatValue
    let fullStars = Int(ratingValue)
    let halfStar = ratingValue - Float(fullStars) >= 0.5 ? 1 : 0
    
    var starImages: [UIImage] = []
    
    // Add full stars
    for _ in 0..<fullStars {
        starImages.append(UIImage(systemName: "star.fill")!) // Replace with your full star image
    }
    // Add half star if applicable
    if halfStar > 0 {
        starImages.append(UIImage(systemName: "star.lefthalf.fill")!) // Replace with your half star image
    }
    // Add empty stars to fill to 5
    let emptyStars = 5 - fullStars - halfStar
    for _ in 0..<emptyStars {
        starImages.append(UIImage(systemName: "star")!) // Replace with your empty star image
    }
    
    // Combine star images into a single image view
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
        let loaderID = ObjectIdentifier(adLoader)
        Task { @MainActor in
            self.handleAdLoaded(loaderID: loaderID, nativeAd: nativeAd)
        }
    }

    nonisolated public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        let loaderID = ObjectIdentifier(adLoader)
        Task { @MainActor in
            self.handleAdFailed(loaderID: loaderID, error: error)
        }
    }
}

@MainActor
private extension NativeAdManager {
    func handleAdLoaded(loaderID: ObjectIdentifier, nativeAd: NativeAd) {
        activeAdLoaders.removeAll { ObjectIdentifier($0) == loaderID }
        #if DEBUG
        print("[NativeAd] loaded.")
        #endif
        self.resetErrorCounter()
        if let (loader, completion) = completionHandlers.first(where: { ObjectIdentifier($0.key) == loaderID }) {
            completion(nativeAd)
            self.completionHandler?(true)
            completionHandlers.removeValue(forKey: loader)
        } else {
            if adCache.count < maxCacheCapacity {
                adCache.append(nativeAd)
                self.completionHandler?(true)
                #if DEBUG
                print("Cached Ads Count: \(NativeAdManager.shared.adCache.count)")
                #endif
            }
        }
    }

    func handleAdFailed(loaderID: ObjectIdentifier, error: Error) {
        activeAdLoaders.removeAll { ObjectIdentifier($0) == loaderID }
        #if DEBUG
        print("[NativeAd] Debug Info: AdUnitID: \(AdsConfig.nativeAdUnitId), Error: \(error)")
        #endif
        self.incrementErrorCounter()
        self.completionHandler?(false)
        if let (loader, completion) = completionHandlers.first(where: { ObjectIdentifier($0.key) == loaderID }) {
            completion(nil)
            completionHandlers.removeValue(forKey: loader)
        }
    }
}

// MARK: - Sendable Conformance for SDK Types
extension NativeAd: @unchecked @retroactive Sendable {}
extension AdLoader: @unchecked @retroactive Sendable {}

// MARK: - Sendable Conformance for SDK Types
import SwiftUI

/// SwiftUI wrapper for Native Ads
public struct NativeAdContainerView: UIViewRepresentable {
    public var adType: AdType = .SMALL
    public var onAdLoaded: ((CGFloat) -> Void)? = nil  // <-- new closure

    public init(adType: AdType = .SMALL,
                onAdLoaded: ((CGFloat) -> Void)? = nil) {
        self.adType = adType
        self.onAdLoaded = onAdLoaded
    }

    public func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        NativeAdManager.shared.getAd(in: containerView, adType: adType) { success in
            #if DEBUG
            print("Native Ad loaded in SwiftUI: \(success)")
            #endif
            if success {
                // Set height according to adType
                let height: CGFloat
                switch adType {
                case .SMALL: height = 120
                case .MEDIUM: height = 300
                case .LARGE: height = 400
                }
                self.onAdLoaded?(height)
            } else {
                self.onAdLoaded?(0) // default 0 if ad failed
            }
        }
        return containerView
    }

    public func updateUIView(_ uiView: UIView, context: Context) { }
}
