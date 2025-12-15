import Foundation
import AppTrackingTransparency
import UIKit
import GoogleMobileAds
import UserMessagingPlatform
@MainActor
public final class AdsManager: NSObject {
    
    /// Configure all ad settings at once
    /// - Parameters:
    ///   - isProduction: True for production AdMob IDs, false for test IDs
    ///   - openAdEnabled: Enable App Open Ads
    ///   - openAdOnLaunchEnabled: Enable Open Ads on Launch
    ///   - bannerAdEnabled: Enable Banner Ads
    ///   - interstitialAdEnabled: Enable Interstitial Ads
    ///   - nativeAdEnabled: Enable Native Ads
    ///   - nativeAdPreloadEnabled: Preload native ads in advance
    ///   - openAdUnitId: Optional App Open Ad Unit ID (default uses placeholder/test ID)
    ///   - bannerAdUnitId: Optional Banner Ad Unit ID (default uses placeholder/test ID)
    ///   - interstitialAdUnitId: Optional Interstitial Ad Unit ID
    ///   - nativeAdUnitId: Optional Native Ad Unit ID
    ///   - interstitialAdShowCount: Max times interstitial can show per session (default 4)
    ///   - maxInterstitialAdsPerSession: Max interstitials per session (default 50)
    ///   - bannerAdErrorCount: Max banner error count (default 7)
    ///   - interstitialAdErrorCount: Max interstitial error count (default 7)
    ///   - nativeAdErrorCount: Max native ad error count (default 7)
    public static func configureAds(
        isProduction: Bool,
        openAdEnabled: Bool,
        openAdOnLaunchEnabled: Bool,
        bannerAdEnabled: Bool,
        interstitialAdEnabled: Bool,
        nativeAdEnabled: Bool,
        nativeAdPreloadEnabled: Bool,
        openAdUnitId: String? = nil,
        bannerAdUnitId: String? = nil,
        interstitialAdUnitId: String? = nil,
        nativeAdUnitId: String? = nil,
        interstitialAdShowCount: Int = 4,
        interstitialAdShowCountOnBack: Int = 5,
        maxInterstitialAdsPerSession: Int = 50,
        bannerAdErrorCount: Int = 7,
        interstitialAdErrorCount: Int = 7,
        nativeAdErrorCount: Int = 7
    ) {
        // Configure AdsConfig with provided or default values
        AdsConfig.isProduction = isProduction
        AdsConfig.openAdEnabled = openAdEnabled
        AdsConfig.openAdOnLaunchEnabled = openAdOnLaunchEnabled
        AdsConfig.bannerAdEnabled = bannerAdEnabled
        AdsConfig.interstitialAdEnabled = interstitialAdEnabled
        AdsConfig.nativeAdEnabled = nativeAdEnabled
        AdsConfig.nativeAdPreloadEnabled = nativeAdPreloadEnabled
        
        AdsConfig.openAdUnitId = openAdUnitId ?? "ca-app-pub-3940256099942544/5575463023"
        AdsConfig.bannerAdUnitId = bannerAdUnitId ?? "ca-app-pub-3940256099942544/2934735716"
        AdsConfig.interstitialAdUnitId = interstitialAdUnitId ?? "ca-app-pub-3940256099942544/4411468910"
        AdsConfig.nativeAdUnitId = nativeAdUnitId ?? "ca-app-pub-3940256099942544/3986624511"
        
        AdsConfig.interstitialAdShowCount = interstitialAdShowCount
        AdsConfig.interstitialAdShowCountOnBack = interstitialAdShowCountOnBack
        AdsConfig.maxInterstitialAdsPerSession = maxInterstitialAdsPerSession
        
        AdsConfig.bannerAdErrorCount = bannerAdErrorCount
        AdsConfig.interstitialAdErrorCount = interstitialAdErrorCount
        AdsConfig.nativeAdErrorCount = nativeAdErrorCount
    }
    
    public static func configure(_ completion: @Sendable @escaping () -> Void) {
        
        // Request ATT first, then UMP consent
        AdsManager.shared.requestATTAuthorization { authorized in
            Task { @MainActor in
                if authorized {
                    AdsManager.shared.requestUMPConsent { _ in
                        Self.startAdsFlow(completion: completion)
                    }
                } else {
                    ConsentInformation.shared.reset()
                    Self.startAdsFlow(completion: completion)
                }
            }
        }
    }
    
    private static func startAdsFlow(completion: @Sendable @escaping () -> Void) {
        MobileAds.shared.start()
        AdsManager.shared.loadInterstitial()
        AdsManager.shared.preloadNativeAds()
        completion()
    }
    
    public static func setToPremium(_ isPremium: Bool) {
        // Save premium state
        AdsConfig.isPremiumUser = isPremium
    }
    
    public static let shared = AdsManager()
    
    // Call this before setupAds
    public func requestATTAuthorization(completion: @Sendable @escaping (Bool) -> Void) {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        print("ATT authorized ✅")
                        completion(true)
                    case .denied:
                        print("ATT denied ❌")
                        completion(false)
                    case .restricted, .notDetermined:
                        print("ATT not determined/restricted ⚠️")
                        completion(false)
                    @unknown default:
                        completion(false)
                    }
                }
            }
        } else {
            // ATT not required below iOS 14
            completion(true)
        }
    }
    
    public var canRequestAds: Bool {
        return ConsentInformation.shared.canRequestAds
    }
    
    public func requestUMPConsent(completion: @Sendable @escaping @MainActor (Bool) -> Void) {
        let parameters = RequestParameters()
        #if DEBUG
        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        #endif
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
            #if DEBUG
            if let error = error {
                print("UMP ConsentInfoUpdate error: \(error.localizedDescription)")
            }
            #endif
            if let _ = error {
                completion(false)
                return
            }
            
            ConsentForm.load { form, loadError in
                #if DEBUG
                if let loadError = loadError {
                    print("UMP ConsentForm load error: \(loadError.localizedDescription)")
                }
                #endif
                if let _ = loadError {
                    completion(false)
                    return
                }
                
                if ConsentInformation.shared.formStatus == .available, let form = form {
                    if let topVC = self.topMostViewController() {
                        form.present(from: topVC) { dismissError in
                            if let _ = dismissError {
                                completion(false)
                                return
                            }
                            completion(ConsentInformation.shared.canRequestAds)
                        }
                    } else {
                        completion(ConsentInformation.shared.canRequestAds)
                    }
                } else {
                    completion(ConsentInformation.shared.canRequestAds)
                }
            }
        }
    }
    
    private func topMostViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        var topController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        return topController
    }
    
    public func resetErrorCounters() {
        BannerAdManager.shared.resetErrorCounter()
        InterstitialAdManager.shared.resetErrorCounter()
        NativeAdManager.shared.resetErrorCounter()
    }
    
    // MARK: - App Open Ad
    public func loadOpenAd() {
        AppOpenAdManager.shared.loadOpenAd()
    }
    
    public func presentAppOpenAdIfAvailable() {
        AppOpenAdManager.shared.tryToPresentAd()
    }
    
    // MARK: - Interstitial Ad
    public func loadInterstitial() {
        InterstitialAdManager.shared.loadAd()
    }
    
    public func showInterstitial(from viewController: UIViewController? = nil,
                                 onBack: Bool = false,
                                 completion: @escaping () -> Void) {
        InterstitialAdManager.shared.showAd(from: viewController, onBack: onBack, completion: completion)
    }
    
    // MARK: - Banner Ad
    public func loadBanner(in containerView: UIView,
                           rootViewController: UIViewController,
                           type: BannerAdType,
                           completion: ((Bool, CGFloat) -> Void)? = nil) {
        BannerAdManager.shared.loadBannerAd(in: containerView, vc: rootViewController, type: type, completion: completion ?? { _, _ in })
    }
    
    // MARK: - Native Ad
    public func preloadNativeAds() {
        NativeAdManager.shared.preloadNativeAds()
    }
    
    public func loadNative(in containerView: UIView,
                           adType: AdType = .SMALL,
                           completion: ((Bool) -> Void)? = nil) {
        NativeAdManager.shared.getAd(in: containerView, adType: adType, completion: completion ?? { _ in })
    }
    
    /// Binds a NativeAd model to a NativeAdView (fills views, hides empty assets, sets nativeAd property).
    public func bindNativeAd(_ nativeAd: NativeAd, to nativeAdView: NativeAdView) {
        // headline & media
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent
        
        // body
        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
        nativeAdView.bodyView?.isHidden = (nativeAd.body == nil)
        
        // call to action
        (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        nativeAdView.callToActionView?.isHidden = (nativeAd.callToAction == nil)
        
        // icon
        (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        nativeAdView.iconView?.isHidden = (nativeAd.icon == nil)
        
        // star rating
        if let starRating = nativeAd.starRating {
            (nativeAdView.starRatingView as? UIImageView)?.image = getStarRatingImage(for: starRating)
            nativeAdView.starRatingView?.isHidden = false
        } else {
            nativeAdView.starRatingView?.isHidden = true
        }
        
        // store / price / advertiser
        (nativeAdView.storeView as? UILabel)?.text = nativeAd.store
        nativeAdView.storeView?.isHidden = (nativeAd.store == nil)
        
        (nativeAdView.priceView as? UILabel)?.text = nativeAd.price
        nativeAdView.priceView?.isHidden = (nativeAd.price == nil)
        
        (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        nativeAdView.advertiserView?.isHidden = (nativeAd.advertiser == nil)
        
        // Ensure CTA doesn't accept user interaction so SDK handles clicks
        nativeAdView.callToActionView?.isUserInteractionEnabled = false
        
        // Associate the view with the ad object (after populating other views)
        nativeAdView.nativeAd = nativeAd
    }
    
}
