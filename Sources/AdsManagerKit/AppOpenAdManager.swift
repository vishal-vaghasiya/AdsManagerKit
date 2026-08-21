@preconcurrency import GoogleMobileAds
import UserMessagingPlatform
import UIKit

// MARK: - AppOpenAdManagerDelegate
@MainActor
public protocol AppOpenAdDelegate: AnyObject {
    func appOpenAdDidComplete()
}

// MARK: - Splash Ad Delegate
@MainActor
public final class SplashAdDelegate: AppOpenAdDelegate {
    public var onComplete: (() -> Void)?

    public init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }

    public func appOpenAdDidComplete() {
        onComplete?()
    }
}

// MARK: - AppOpenAdManager
@MainActor
// [START app_open_ad_manager]
final class AppOpenAdManager: NSObject {
    // The app open ad.
    private var appOpenAd: AppOpenAd?
    
    /// Delegate for App Open Ad events.
    weak var delegate: AppOpenAdDelegate?
    
    /// Keeps track of if an app open ad is loading.
    private var isLoadingAd = false
    
    /// Keeps track of if an app open ad is showing.
    private var isShowingAd = false
    
    /// Keeps track of the time when an app open ad was loaded to discard expired ad.
    private var adLoadTime: Date?
    
    private let adValidityDuration: TimeInterval = 4 * 3_600
    
    static let shared = AppOpenAdManager()
    
    // MARK: - Private Methods
    
    private func wasLoadTimeLessThanNHoursAgo(timeoutInterval: TimeInterval) -> Bool {
        if let adLoadTime = adLoadTime {
            return Date().timeIntervalSince(adLoadTime) < timeoutInterval
        }
        return false
    }
    
    private func isAdAvailable() -> Bool {
        return appOpenAd != nil &&
        wasLoadTimeLessThanNHoursAgo(timeoutInterval: adValidityDuration)
    }
    
    private func createAdRequest() -> Request/*AdManagerRequest*/ {
        // Latest UMP SDK automatically handles ATT/GDPR
        return Request()//)AdManagerRequest()
    }
    
    public func loadOpenAd() async {
        // Do not load ad if there is an unused ad or one is already loading.
        if isLoadingAd || isAdAvailable() {
            return
        }

        guard AdsConfig.openAdEnabled else {
            return
        }

        guard ConsentInformation.shared.canRequestAds else {
            #if DEBUG
            print(
                "[AppOpenAd] ⛔️ Consent not granted. " +
                "Skipping load."
            )
            #endif
            return
        }
        
        isLoadingAd = true

        do {
            appOpenAd = try await AppOpenAd.load(
                with: AdsConfig.openAdUnitId,
                request: createAdRequest()
            )

            appOpenAd?.fullScreenContentDelegate = self
            adLoadTime = Date()

            #if DEBUG
            print("[AppOpenAd] loaded.")
            #endif

        } catch {
            appOpenAd = nil
            adLoadTime = nil

            #if DEBUG
            print("[AppOpenAd] Failed to load: \(error.localizedDescription)")
            #endif
        }

        isLoadingAd = false
    }
    
    func tryToPresentAd() {
        // If the app open ad is already showing, do not show the ad again.
        if isShowingAd {
            #if DEBUG
            print("[AppOpenAd] is already showing.")
            #endif
            return
        }
        
        // If the app open ad is not available yet but is supposed to show, load
        // a new ad.
        if !isAdAvailable() {
            #if DEBUG
            print("[AppOpenAd] is not ready yet.")
            #endif
            
            // The app open ad is considered to be complete in this example.
            delegate?.appOpenAdDidComplete()
            
            // [START_EXCLUDE silent]
            Task {
                await loadOpenAd()
            }
            
            // [END_EXCLUDE]
            return
        }
        
        if let appOpenAd {
            // Remove the ad reference before presenting
            // so the same ad cannot be presented twice.
            
            #if DEBUG
            print("[AppOpenAd] will be displayed.")
            #endif
            
            appOpenAd.present(from: nil)
            isShowingAd = true
        }
    }
    
    func tryToPresentSplashAd() {
        guard AdsConfig.openAdEnabled,
              AdsConfig.openAdOnSplashEnabled else {
            // The app open ad is considered to be complete in this example.
            delegate?.appOpenAdDidComplete()
            return
        }
        tryToPresentAd()
    }
}

// MARK: - FullScreenContentDelegate

extension AppOpenAdManager: FullScreenContentDelegate {
    // [START ad_events]
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[AppOpenAd] recorded an impression")
        #endif
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[AppOpenAd] recorded a click")
        #endif
    }

    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[AppOpenAd] will be dismissed")
        #endif
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[AppOpenAd] Will present")
        #endif
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[AppOpenAd] dismissed")
        #endif
        
        appOpenAd = nil
        isShowingAd = false
        
        delegate?.appOpenAdDidComplete()
        
        // Preload the next App Open Ad.
        Task {
            await loadOpenAd()
        }
    }
    
    public func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        #if DEBUG
        print("[AppOpenAd] Failed to present: \(error.localizedDescription)")
        #endif
        
        appOpenAd = nil
        isShowingAd = false
        
        delegate?.appOpenAdDidComplete()
        
        // Preload the next App Open Ad.
        Task {
            await loadOpenAd()
        }
    }
}
