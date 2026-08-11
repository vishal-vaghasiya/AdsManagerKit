@preconcurrency import GoogleMobileAds
import AppTrackingTransparency
import UserMessagingPlatform
import UIKit

@MainActor
public final class InterstitialAdManager: NSObject, FullScreenContentDelegate {
    
    public static let shared = InterstitialAdManager()
    
    private var interstitialAd: InterstitialAd?
    private var displayCounter: Int = 0
    private var sessionLimitCounter: Int = 0
    private var isLoadingAd = false
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
    
    private func createAdRequest() -> Request {
        return Request() // Latest UMP SDK automatically handles ATT/GDPR
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
    
    /// Load the interstitial ad
    func loadAd() async {
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
            let request = createAdRequest()

            let ad = try await InterstitialAd.load(
                with: AdsConfig.interstitialAdUnitId,
                request: request
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
    func showAd() {
        guard ConsentInformation.shared.canRequestAds else {
            #if DEBUG
            print("[InterstitialAd] ⛔️ Consent not granted (canRequestAds = false). Skipping show.")
            #endif
            return
        }
        
        guard AdsConfig.interstitialAdEnabled else {
            return
        }
        
        guard sessionLimitCounter < AdsConfig.maxInterstitialAdsPerSession else {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Session limit reached — skipping show.")
            #endif
            return
        }
        
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
            return
        }
        
        guard let ad = interstitialAd else {
            #if DEBUG
            print("[InterstitialAd] ℹ️ Ad not ready — loading for next opportunity.")
            #endif
            Task {
                await loadAd()
            }
            return
        }
        
        guard isInterstitialAdValid else {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Cached ad expired — discarding and reloading.")
            #endif
            
            interstitialAd = nil
            interstitialAdLoadTime = nil
            Task {
                await loadAd()
            }
            return
        }
        
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            
            #if DEBUG
            print("[InterstitialAd] ❌ Could not find root view controller.")
            #endif
            
            return
        }
        
        do {
            try ad.canPresent(from: rootViewController)
        } catch {
            #if DEBUG
            print("[InterstitialAd] ❌ Ad cannot be presented: \(error.localizedDescription)")
            #endif
            
            interstitialAd = nil
            interstitialAdLoadTime = nil
            
            Task {
                await loadAd()
            }
            return
        }
        
        if AdsConfig.showLoadingIndicator {
            AppProgressHUD.show(status: "Preparing ad...")
            
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                guard let self else { return }
                
                AppProgressHUD.dismiss()
                
                self.displayCounter = 0
                self.sessionLimitCounter += 1
                self.lastInterstitialShownAt = Date()
                self.resetErrorCounter()
                
                ad.present(from: rootViewController)
            }

            return
        }
        
        // No loader — present immediately
        displayCounter = 0
        sessionLimitCounter += 1
        lastInterstitialShownAt = Date()
        resetErrorCounter()
        
        ad.present(from: rootViewController)
    }
    
    // MARK: - GADFullScreenContentDelegate
    
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[InterstitialAd] Dismissed")
        #endif

        interstitialAd = nil
        interstitialAdLoadTime = nil
        Task {
            await loadAd()
        }
    }
    
    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        #if DEBUG
        print("[InterstitialAd] Failed to present: \(error.localizedDescription)")
        #endif

        interstitialAd = nil
        interstitialAdLoadTime = nil
        Task {
            await loadAd()
        }
    }
    
    public func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[InterstitialAd] Will present")
        #endif
    }
}
