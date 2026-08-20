@preconcurrency import GoogleMobileAds
import AppTrackingTransparency
import UserMessagingPlatform
import UIKit

@MainActor
final class InterstitialAdManager: NSObject, FullScreenContentDelegate {
    
    public static let shared = InterstitialAdManager()
    
    private var interstitialAd: InterstitialAd?
    private var displayCounter: Int = 0
    private var sessionLimitCounter: Int = 0
    private var isLoadingAd = false
    private var isPresentingAd = false
    private var lastInterstitialShownAt: Date?
    private let interstitialCooldown: TimeInterval = 75
    
    private var interstitialAdLoadTime: Date?
    private let interstitialAdValidityDuration: TimeInterval = 55 * 60
    private var isInterstitialAdValid: Bool {
        guard let loadTime = interstitialAdLoadTime else {
            return false
        }

        return Date().timeIntervalSince(loadTime) < interstitialAdValidityDuration
    }
    
    public func resetErrorCounter() {
        AdsConfig.currentInterstitialAdErrorCount = 0
    }
    
    private func incrementErrorCounter() {
        AdsConfig.currentInterstitialAdErrorCount += 1
    }
    
    private func hasExceededErrorLimit() -> Bool {
        return AdsConfig.currentInterstitialAdErrorCount >= AdsConfig.interstitialAdErrorCount
    }
    
    private func clearAd() {
        interstitialAd = nil
        interstitialAdLoadTime = nil
    }
    
    private func topViewController(
        from viewController: UIViewController
    ) -> UIViewController {

        if let presentedViewController = viewController.presentedViewController {
            return topViewController(from: presentedViewController)
        }

        if let navigationController = viewController as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return topViewController(from: visibleViewController)
        }

        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return topViewController(from: selectedViewController)
        }

        return viewController
    }
    
    private func presentingViewController() -> UIViewController? {

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

        return topViewController(from: rootViewController)
    }
    
    /// Load the interstitial ad
    public func loadAd() async {
        guard ConsentInformation.shared.canRequestAds else {
            #if DEBUG
            print("[InterstitialAd] ⛔️ Consent not granted (canRequestAds = false). Skipping load.")
            #endif
            return
        }

        guard AdsConfig.interstitialAdEnabled else {
            return
        }

        guard sessionLimitCounter < AdsConfig.maxInterstitialAdsPerSession else {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Session limit reached — not loading.")
            #endif
            return
        }

        guard !hasExceededErrorLimit() else {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Max error attempts reached — not loading.")
            #endif
            return
        }

        guard interstitialAd == nil else {
            return
        }

        guard !isLoadingAd else {
            return
        }

        isLoadingAd = true
        defer {
            isLoadingAd = false
        }

        do {
            let ad = try await InterstitialAd.load(
                with: AdsConfig.interstitialAdUnitId,
                request: Request()
            )

            resetErrorCounter()

            interstitialAd = ad
            interstitialAdLoadTime = Date()
            ad.fullScreenContentDelegate = self

            #if DEBUG
            print("[InterstitialAd] ✅ Loaded and ready.")
            #endif

        } catch {
            incrementErrorCounter()

            #if DEBUG
            print("[InterstitialAd] ❌ Failed to load: \(error.localizedDescription)")
            print("[InterstitialAd] Error count: \(AdsConfig.currentInterstitialAdErrorCount)/\(AdsConfig.interstitialAdErrorCount)")
            #endif
        }
    }
    
    /// Show the interstitial ad if available
    public func showAd() {

        // MARK: Prevent duplicate presentation

        guard !isPresentingAd else {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Ad is already being presented.")
            #endif
            return
        }

        // MARK: App must be active

        guard UIApplication.shared.applicationState == .active else {
            #if DEBUG
            print("[InterstitialAd] ⚠️ App is not active — skipping show.")
            #endif
            return
        }

        // MARK: Consent

        guard ConsentInformation.shared.canRequestAds else {
            #if DEBUG
            print("[InterstitialAd] ⛔️ Consent not granted — skipping show.")
            #endif
            return
        }

        // MARK: Ads enabled

        guard AdsConfig.interstitialAdEnabled else {
            return
        }

        // MARK: Session limit

        guard sessionLimitCounter < AdsConfig.maxInterstitialAdsPerSession else {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Session limit reached — skipping show.")
            #endif
            return
        }

        // MARK: Frequency control

        let shouldShowByCount =
            displayCounter >= AdsConfig.interstitialAdShowCount

        let shouldShowByTime: Bool = {
            guard let lastShown = lastInterstitialShownAt else {
                return true
            }

            return Date().timeIntervalSince(lastShown) >= interstitialCooldown
        }()

        guard shouldShowByCount || shouldShowByTime else {
            displayCounter += 1

            #if DEBUG
            print("[InterstitialAd] ℹ️ Frequency condition not met.")
            print("[InterstitialAd] Display counter: \(displayCounter)")
            #endif

            return
        }

        // MARK: Ad availability

        guard let ad = interstitialAd else {
            #if DEBUG
            print("[InterstitialAd] ℹ️ Ad not ready — loading for next opportunity.")
            #endif

            Task { @MainActor [weak self] in
                await self?.loadAd()
            }

            return
        }

        // MARK: Ad validity

        guard isInterstitialAdValid else {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Cached ad expired — discarding and reloading.")
            #endif

            clearAd()

            Task { @MainActor [weak self] in
                await self?.loadAd()
            }

            return
        }

        // MARK: Find current presenter

        guard let presentingViewController = presentingViewController() else {
            #if DEBUG
            print("[InterstitialAd] ❌ Could not find presenting view controller.")
            #endif
            return
        }

        // MARK: Verify presentation

        do {
            try ad.canPresent(from: presentingViewController)
        } catch {
            #if DEBUG
            print("[InterstitialAd] ❌ Ad cannot be presented: \(error.localizedDescription)")
            #endif

            clearAd()

            Task { @MainActor [weak self] in
                await self?.loadAd()
            }

            return
        }

        // MARK: Update state before presentation

        isPresentingAd = true
        displayCounter = 0
        sessionLimitCounter += 1
        lastInterstitialShownAt = Date()

        // MARK: Present

        #if DEBUG
        print("[InterstitialAd] ✅ Presenting interstitial ad.")
        #endif

        ad.present(from: presentingViewController)
    }
    
    // MARK: - GADFullScreenContentDelegate
    
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {

        #if DEBUG
        print("[InterstitialAd] Dismissed")
        #endif

        isPresentingAd = false
        clearAd()

        Task { @MainActor [weak self] in
            await self?.loadAd()
        }
    }
    
    public func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {

        #if DEBUG
        print("[InterstitialAd] ❌ Failed to present: \(error.localizedDescription)")
        #endif

        isPresentingAd = false
        clearAd()

        Task { @MainActor [weak self] in
            await self?.loadAd()
        }
    }
    
    public func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[InterstitialAd] Will present")
        #endif
    }
}
