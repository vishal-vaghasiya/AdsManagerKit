@preconcurrency import GoogleMobileAds
import AppTrackingTransparency
import UserMessagingPlatform
import UIKit

@MainActor
public final class InterstitialAdManager: NSObject, FullScreenContentDelegate {
    
    public static let shared = InterstitialAdManager()
    
    private var interstitialAd: InterstitialAd?
    private var completionHandler: (() -> Void)?
    private var displayCounter: Int = 0
    private var sessionLimitCounter: Int = 0
    private var isLoadingAd = false
    private var lastInterstitialShownAt: Date?
    private let interstitialCooldown: TimeInterval = 75
    
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
    func loadAd() {
        guard AdsConfig.interstitialAdEnabled,
              sessionLimitCounter < AdsConfig.maxInterstitialAdsPerSession else {
            return
        }
        
        guard !hasExceededErrorLimit() else {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Max error attempts reached — not loading.")
            #endif
            return
        }
        
        guard interstitialAd == nil else { return }
        guard !isLoadingAd else { return }
        isLoadingAd = true
        
        InterstitialAd.load(with: AdsConfig.interstitialAdUnitId, request: createAdRequest()) { [weak self] ad, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isLoadingAd = false
                
                if let error = error {
                    #if DEBUG
                    print("[InterstitialAd] Failed to load: \(error.localizedDescription)")
                    #endif
                    self.incrementErrorCounter()
                    self.isLoadingAd = false
                    return
                }
                
                self.resetErrorCounter()
                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                #if DEBUG
                print("[InterstitialAd] loaded and ready.")
                #endif
            }
        }
    }
    
    /// Show the ad if available, then run completion
    func showAd(from viewController: UIViewController? = nil, completion: @escaping () -> Void) {
        guard AdsConfig.interstitialAdEnabled else {
            completion()
            return
        }
        
        var presentingVC = viewController
        
        if presentingVC == nil {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Warning: Passing nil viewController in UIKit context may not be safe.")
            #endif
            // Fallback to topMostViewController for SwiftUI usage
            presentingVC = UIApplication.shared.topMostViewController()
        }
        
        guard sessionLimitCounter < AdsConfig.maxInterstitialAdsPerSession else {
            completion()
            return
        }
        
        guard let ad = interstitialAd else {
            completion()
            DispatchQueue.main.async {
                self.loadAd()
            }
            return
        }
        
        let shouldShowByCount = displayCounter >= AdsConfig.interstitialAdShowCount
        let shouldShowByTime: Bool = {
            guard let lastShown = lastInterstitialShownAt else { return true }
            return Date().timeIntervalSince(lastShown) >= interstitialCooldown
        }()
        
        if shouldShowByCount || shouldShowByTime {
            displayCounter = 1
            sessionLimitCounter += 1
            resetErrorCounter()
            
            lastInterstitialShownAt = Date()
            completionHandler = completion
            ad.present(from: presentingVC)
        } else {
            displayCounter += 1
            completion()
        }
    }
    
    // MARK: - GADFullScreenContentDelegate
    
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[InterstitialAd] Dismissed")
        #endif
        interstitialAd = nil
        loadAd()
        completionHandler?()
        completionHandler = nil
    }
    
    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        #if DEBUG
        print("[InterstitialAd] Failed to present: \(error.localizedDescription)")
        #endif
        interstitialAd = nil
        loadAd()
        completionHandler?()
        completionHandler = nil
    }
    
    public func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[InterstitialAd] Will present")
        #endif
    }
}

extension UIApplication {
    func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
            if let nav = base as? UINavigationController {
                return topMostViewController(base: nav.visibleViewController)
            }
            if let tab = base as? UITabBarController {
                if let selected = tab.selectedViewController {
                    return topMostViewController(base: selected)
                }
            }
            if let presented = base?.presentedViewController {
                return topMostViewController(base: presented)
            }
            return base
        }
}
