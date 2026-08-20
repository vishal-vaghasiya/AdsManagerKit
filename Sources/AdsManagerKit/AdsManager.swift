import Foundation
import AppTrackingTransparency
import UIKit
import GoogleMobileAds
import UserMessagingPlatform
@MainActor
public final class AdsManager: NSObject {
    
    public static let shared = AdsManager()
    private var isMobileAdsStartCalled = false
    public var isAdsStarted: Bool {
        return isMobileAdsStartCalled
    }
    
    /// Configure all ad settings at once
    /// - Parameters:
    ///   - isProduction: True for production AdMob IDs, false for test IDs
    ///   - openAdEnabled: Enable App Open Ads
    ///   - openAdOnSplashEnabled: Controls whether an App Open Ad can be shown on the Splash screen.
    ///     This does not affect App Open Ads shown when the app returns from the background.
    ///   - bannerAdEnabled: Enable Banner Ads
    ///   - interstitialAdEnabled: Enable Interstitial Ads
    ///   - nativeAdEnabled: Enable Native Ads
    ///   - openAdUnitId: Optional App Open Ad Unit ID (default uses placeholder/test ID)
    ///   - bannerAdUnitId: Optional Banner Ad Unit ID (default uses placeholder/test ID)
    ///   - interstitialAdUnitId: Optional Interstitial Ad Unit ID
    ///   - nativeAdUnitId: Optional Native Ad Unit ID
    ///   - interstitialAdShowCount: Max times interstitial can show per session (default 4)
    ///   - maxInterstitialAdsPerSession: Max interstitials per session (default 10)
    ///   - bannerAdErrorCount: Max banner error count (default 5)
    ///   - interstitialAdErrorCount: Max interstitial error count (default 5)
    ///   - nativeAdErrorCount: Max native ad error count (default 5)
    public static func configureAds(
        isProduction: Bool,
        openAdEnabled: Bool,
        openAdOnSplashEnabled: Bool,
        bannerAdEnabled: Bool,
        interstitialAdEnabled: Bool,
        nativeAdEnabled: Bool,
        openAdUnitId: String? = nil,
        bannerAdUnitId: String? = nil,
        interstitialAdUnitId: String? = nil,
        nativeAdUnitId: String? = nil,
        nativeAdPreloadEnabled: Bool,
        nativeAdPreloadCount: Int,
        interstitialAdShowCount: Int = 4,
        maxInterstitialAdsPerSession: Int = 10,
        bannerAdErrorCount: Int = 5,
        interstitialAdErrorCount: Int = 5,
        nativeAdErrorCount: Int = 5
    ) {
        // Configure AdsConfig with provided or default values
        AdsConfig.isProduction = isProduction
        
        AdsConfig.openAdEnabled = openAdEnabled
        AdsConfig.openAdOnSplashEnabled = openAdOnSplashEnabled
        AdsConfig.bannerAdEnabled = bannerAdEnabled
        AdsConfig.interstitialAdEnabled = interstitialAdEnabled
        AdsConfig.nativeAdEnabled = nativeAdEnabled
        
        AdsConfig.openAdUnitId = openAdUnitId ?? "ca-app-pub-3940256099942544/5575463023"
        AdsConfig.bannerAdUnitId = bannerAdUnitId ?? "ca-app-pub-3940256099942544/2934735716"
        AdsConfig.interstitialAdUnitId = interstitialAdUnitId ?? "ca-app-pub-3940256099942544/4411468910"
        AdsConfig.nativeAdUnitId = nativeAdUnitId ?? "ca-app-pub-3940256099942544/3986624511"
        
        AdsConfig.interstitialAdShowCount = interstitialAdShowCount
        AdsConfig.maxInterstitialAdsPerSession = maxInterstitialAdsPerSession
        
        AdsConfig.nativeAdPreloadEnabled = nativeAdPreloadEnabled
        AdsConfig.nativeAdPreloadCount = nativeAdPreloadCount
        
        AdsConfig.bannerAdErrorCount = bannerAdErrorCount
        AdsConfig.interstitialAdErrorCount = interstitialAdErrorCount
        AdsConfig.nativeAdErrorCount = nativeAdErrorCount
    }
    
    public static func configure(completion: (() -> Void)? = nil) {
        // Gather / update consent.
        AdsManager.shared.requestUMPConsent { canRequestAds in
            if canRequestAds {
                AdsManager.startAdsFlow()
            }
            completion?()
        }
        
        // Start ads immediately if valid consent was already obtained
        // in a previous session.
        if AdsManager.shared.canRequestAds {
            AdsManager.startAdsFlow()
        }
    }
    
    private static func startAdsFlow() {
        let manager = AdsManager.shared
        
        // Prevent Google Mobile Ads SDK from being initialized more than once.
        guard !manager.isMobileAdsStartCalled else {
            return
        }
        
        manager.isMobileAdsStartCalled = true
        
        // Initialize Google Mobile Ads SDK once.
        MobileAds.shared.start()
        
        // Preload App Open Ad.
        if AdsConfig.openAdEnabled && AdsConfig.openAdOnSplashEnabled {
            Task {
                await AppOpenAdManager.shared.loadOpenAd()
            }
        }
        
        // Preload Interstitial Ad.
        if AdsConfig.interstitialAdEnabled {
            Task {
                await InterstitialAdManager.shared.loadAd()
            }
        }
        
        // Preload Native Ad.
        if AdsConfig.nativeAdEnabled && AdsConfig.nativeAdPreloadEnabled {
            if let rootViewController = AdsManager.shared.topMostViewController() {
                Task {
                    await NativeAdManager.shared.preloadNativeAds(rootViewController: rootViewController)
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
                #if DEBUG
                print("UMP consent error: \(error.localizedDescription)")
                #endif
                
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
    public func tryToPresentSplashAd(delegate: AppOpenAdDelegate? = nil) {
        AppOpenAdManager.shared.delegate = delegate
        AppOpenAdManager.shared.tryToPresentSplashAd()
    }
    
    public func showAppOpenAdIfAvailable() {
        AppOpenAdManager.shared.tryToPresentAd()
    }
    
    // MARK: - Interstitial Ad
    public func loadInterstitial() {
        Task { @MainActor in
            await InterstitialAdManager.shared.loadAd()
        }
    }

    public func showInterstitialIfAvailable() {
        InterstitialAdManager.shared.showAd()
    }
    
    // MARK: - Banner Ad
    public func loadBannerAd(in containerView: UIView,
                           rootViewController: UIViewController,
                           type: BannerAdType,
                           completion: ((Bool, CGFloat) -> Void)? = nil) {
        BannerAdManager.shared.loadBannerAd(in: containerView, vc: rootViewController, type: type, completion: completion ?? { _, _ in })
    }
    
    // MARK: - Native Ad
    public func loadNativeAd(
        in containerView: UIView,
        rootViewController: UIViewController,
        adView: NativeAdView,
        height: CGFloat,
        completion: ((Bool, CGFloat) -> Void)? = nil) {
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
