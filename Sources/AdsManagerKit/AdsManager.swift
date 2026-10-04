import Foundation
import UIKit
import GoogleMobileAds
import UserMessagingPlatform
@MainActor
public final class AdsManager: NSObject {
    
    public static let shared = AdsManager()
    private var hasStartedMobileAds = false
    
    public var isAdsStarted: Bool {
        hasStartedMobileAds
    }
    
    public static func initialize(
        with configuration: AppConfiguration?,
        completion: (() -> Void)? = nil
    ) {
        if let configuration {
            applyConfiguration(configuration)
        }
        let manager = AdsManager.shared
        
        // Gather / update consent.
        manager.requestUMPConsent { canRequestAds in
            if canRequestAds {
                startGoogleMobileAdsSDK()
            }
            
            completion?()
        }
        
        // Start ads immediately if valid consent was already obtained
        // in a previous session.
        if manager.canRequestAds {
            startGoogleMobileAdsSDK()
        }
    }
    
    private static func applyConfiguration(
        _ configuration: AppConfiguration
    ) {
        
        // MARK: - Features
        
        AdsConfig.isOpenAdEnabled =
        configuration.features.isOpenAdEnabled
        
        AdsConfig.isOpenAdOnSplashEnabled =
        configuration.features.isOpenAdOnSplashEnabled
        
        AdsConfig.splashDelaySeconds =
        configuration.timing.splashDelaySeconds
        
        AdsConfig.isBannerAdEnabled =
        configuration.features.isBannerEnabled
        
        AdsConfig.isInterstitialAdEnabled =
        configuration.features.isFullScreenEnabled
        
        AdsConfig.isNativeAdEnabled =
        configuration.features.isNativeEnabled
        
        AdsConfig.isNativeAdPreloadEnabled =
        configuration.features.isNativePreloadEnabled
        
        // MARK: - Ad Unit IDs
        
        AdsConfig.openAdUnitID =
        configuration.identifiers.openAd
        
        AdsConfig.bannerAdUnitID =
        configuration.identifiers.banner
        
        AdsConfig.interstitialAdUnitID =
        configuration.identifiers.fullScreen
        
        AdsConfig.nativeAdUnitID =
        configuration.identifiers.native
        
        // MARK: - Limits
        
        AdsConfig.interstitialAdShowCount =
        configuration.limits.frequency
        
        AdsConfig.maxInterstitialAdsPerSession =
        configuration.limits.session
        
        AdsConfig.nativeAdPreloadCount =
        configuration.limits.nativePreloadCount
        
        AdsConfig.bannerAdErrorCount =
        configuration.limits.bannerErrors
        
        AdsConfig.interstitialAdErrorCount =
        configuration.limits.fullScreenErrors
        
        AdsConfig.nativeAdErrorCount =
        configuration.limits.nativeErrors
    }
    
    private static func startGoogleMobileAdsSDK() {
        let manager = AdsManager.shared
        
        // Prevent Google Mobile Ads SDK from being initialized more than once.
        guard !manager.hasStartedMobileAds else {
            return
        }
        
        manager.hasStartedMobileAds = true
        
        // Initialize Google Mobile Ads SDK once.
        MobileAds.shared.start()
        
        // Preload App Open Ad.
        if AdsConfig.isOpenAdEnabled {
            Task {
                await AppOpenAdManager.shared.loadOpenAd()
            }
        }
        
        // Preload Interstitial Ad.
        if AdsConfig.isInterstitialAdEnabled {
            Task {
                await InterstitialAdManager.shared.loadAd()
            }
        }
        
        // Preload Native Ads.
        if AdsConfig.isNativeAdEnabled &&
            AdsConfig.isNativeAdPreloadEnabled {
            
            if let rootViewController = manager.topMostViewController() {
                Task {
                    await NativeAdManager.shared.preloadNativeAds(
                        rootViewController: rootViewController
                    )
                }
            }
        }
    }
    
    public static func setToPremium(_ isPremium: Bool) {
        // Save premium state
        AdsConfig.isPremiumUser = isPremium
    }
    
    public var canRequestAds: Bool {
        return ConsentInformation.shared.canRequestAds
    }
    
    public func requestUMPConsent(
        completion: @Sendable @escaping @MainActor (Bool) -> Void
    ) {
        let parameters = RequestParameters()
        
        Task { @MainActor in
            do {
                try await ConsentInformation.shared.requestConsentInfoUpdate(
                    with: parameters
                )
                
                guard let topVC = self.topMostViewController() else {
                    completion(ConsentInformation.shared.canRequestAds)
                    return
                }
                
                try await ConsentForm.loadAndPresentIfRequired(
                    from: topVC
                )
                
                completion(ConsentInformation.shared.canRequestAds)
            } catch {
                completion(ConsentInformation.shared.canRequestAds)
            }
        }
    }
    
    private func topMostViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return nil
        }
        
        guard let rootViewController = windowScene.windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            return nil
        }
        
        return findTopViewController(from: rootViewController)
    }
    
    private func findTopViewController(
        from viewController: UIViewController
    ) -> UIViewController {
        
        if let presentedViewController = viewController.presentedViewController {
            return findTopViewController(from: presentedViewController)
        }
        
        if let navigationController = viewController as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return findTopViewController(from: visibleViewController)
        }
        
        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return findTopViewController(from: selectedViewController)
        }
        
        if let splitViewController = viewController as? UISplitViewController,
           let lastViewController = splitViewController.viewControllers.last {
            return findTopViewController(from: lastViewController)
        }
        
        return viewController
    }
    
    // MARK: - AppOpen Ad
    public func tryToPresentSplashAd(
        delegate: AppOpenAdDelegate? = nil
    ) {
        guard AdsConfig.isOpenAdEnabled,
              AdsConfig.isOpenAdOnSplashEnabled else {
            delegate?.appOpenAdDidComplete()
            return
        }
        
        AppOpenAdManager.shared.delegate = delegate
        AppOpenAdManager.shared.tryToPresentSplashAd()
    }
    
    public func showAppOpenAdIfAvailable() {
        guard AdsConfig.isOpenAdEnabled else {
            return
        }
        
        AppOpenAdManager.shared.tryToPresentAd()
    }
    
    // MARK: - Interstitial Ad
    public func loadInterstitial() {
        guard AdsConfig.isInterstitialAdEnabled else {
            return
        }
        
        Task { @MainActor in
            await InterstitialAdManager.shared.loadAd()
        }
    }
    
    public func showInterstitialIfAvailable() {
        guard AdsConfig.isInterstitialAdEnabled else {
            return
        }
        
        InterstitialAdManager.shared.showAd()
    }
    
    // MARK: - Banner Ad
    public func loadBannerAd(
        in containerView: UIView,
        rootViewController: UIViewController,
        type: BannerAdType,
        completion: ((Bool, CGFloat) -> Void)? = nil
    ) {
        guard AdsConfig.isBannerAdEnabled else {
            completion?(false, 0)
            return
        }
        
        BannerAdManager.shared.loadBannerAd(
            in: containerView,
            vc: rootViewController,
            type: type,
            completion: completion ?? { _, _ in }
        )
    }
    
    // MARK: - Native Ad
    public func loadNativeAd(
        in containerView: UIView,
        rootViewController: UIViewController,
        adView: NativeAdView,
        height: CGFloat,
        completion: ((Bool, CGFloat) -> Void)? = nil
    ) {
        guard AdsConfig.isNativeAdEnabled else {
            completion?(false, 0)
            return
        }
        
        NativeAdManager.shared.loadNativeAd(
            in: containerView,
            viewController: rootViewController,
            adView: adView,
            height: height,
            completion: completion ?? { _, _ in }
        )
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
