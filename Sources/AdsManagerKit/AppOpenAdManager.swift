@preconcurrency import GoogleMobileAds
import UserMessagingPlatform
import UIKit

// MARK: - AppOpenAdManager
@MainActor
// [START app_open_ad_manager]
public final class AppOpenAdManager: NSObject {
    // The app open ad.
    private var appOpenAd: AppOpenAd?
    /// Maintains a reference to the delegate.
    private var appOpenAdManagerAdDidComplete: (@Sendable () -> Void)?
    private var didFirstLoadFail = false
    
    /// Keeps track of if an app open ad is loading.
    private var isLoadingAd = false
    /// Keeps track of if an app open ad is showing.
    private var isShowingAd = false
    /// Keeps track of the time when an app open ad was loaded to discard expired ad.
    private var adLoadTime: Date?
    private let adValidityDuration: TimeInterval = 4 * 3_600
    
    public static let shared = AppOpenAdManager()
    // MARK: - Private Methods
    
    private func wasLoadTimeLessThanNHoursAgo(timeoutInterval: TimeInterval) -> Bool {
        if let adLoadTime = adLoadTime {
            return Date().timeIntervalSince(adLoadTime) < timeoutInterval
        }
        return false
    }
    
    private func isAdAvailable() -> Bool {
        return appOpenAd != nil && wasLoadTimeLessThanNHoursAgo(timeoutInterval: adValidityDuration)
    }
    
    private func createAdRequest() -> Request {
        // Latest UMP SDK automatically handles ATT/GDPR
        return Request()
    }
    
    func loadOpenAd() {
        guard ConsentInformation.shared.canRequestAds else {
            #if DEBUG
            print("[AppOpenAd] ⛔️ Consent not granted (canRequestAds = false). Skipping preload.")
            #endif
            return
        }
        if isLoadingAd || isAdAvailable() {
            return
        }
        if AdsConfig.openAdEnabled {
            isLoadingAd = true
            AppOpenAd.load(with: AdsConfig.openAdUnitId, request: createAdRequest()) { [weak self] ad, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error = error {
                        self.isLoadingAd = false
                        self.appOpenAd = nil
                        self.adLoadTime = nil
                        #if DEBUG
                        print("[AppOpenAd] Failed to load: \(error)")
                        #endif
                        return
                    }
                    self.appOpenAd = ad
                    self.appOpenAd?.fullScreenContentDelegate = self
                    self.adLoadTime = Date()
                    self.isLoadingAd = false
                    #if DEBUG
                    print("[AppOpenAd] loaded.")
                    #endif
                }
            }
        }
    }
    
    func tryToPresentAd() {
        guard ConsentInformation.shared.canRequestAds else {
            #if DEBUG
            print("[AppOpenAd] ⛔️ Consent not granted (canRequestAds = false). Skipping show.")
            #endif
            return
        }
        // If the app open ad is already showing, do not show the ad again.
        if isShowingAd {
            #if DEBUG
            print("[AppOpenAd] is already showing.")
            #endif
            return
        }
        
        if !isAdAvailable() {
            #if DEBUG
            print("[AppOpenAd] is not ready yet.")
            #endif
            loadOpenAd()
            return
        }
        
        if let ad = appOpenAd {
            #if DEBUG
            print("[AppOpenAd] will be displayed.")
            #endif
            isShowingAd = true
            ad.present(from: nil)
        }
    }
}

// MARK: - FullScreenContentDelegate

extension AppOpenAdManager: FullScreenContentDelegate {
    
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[AppOpenAd] Dismissed")
        #endif
        appOpenAd = nil
        isShowingAd = false
        appOpenAdManagerAdDidComplete?()
        loadOpenAd()
    }
    
    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        #if DEBUG
        print("[AppOpenAd] Failed to present: \(error.localizedDescription)")
        #endif
        appOpenAd = nil
        isShowingAd = false
        appOpenAdManagerAdDidComplete?()
        loadOpenAd()
    }
    
    public func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[AppOpenAd] Will present")
        #endif
    }
}
