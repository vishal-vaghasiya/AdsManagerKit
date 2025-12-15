@preconcurrency import GoogleMobileAds
import AppTrackingTransparency
import UserMessagingPlatform
import UIKit

@MainActor
public final class InterstitialAdManager: NSObject, FullScreenContentDelegate {
    
    public static let shared = InterstitialAdManager()
    
    private var interstitialAd: InterstitialAd?
    private var completionHandler: (() -> Void)?
    var displayCounter: Int = 0
    var displayCounterOnBack: Int = 0
    var displayLimitCounter: Int = 0
    
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
    
    public func loadAndShow(from viewController: UIViewController? = nil, completion: @escaping () -> Void) {
        if !AdsConfig.interstitialAdEnabled {
            completion()
            return
        }
        
        self.completionHandler = completion
        
        var presentingVC = viewController
        
        if presentingVC == nil {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Warning: Passing nil viewController in UIKit context may not be safe.")
            #endif
            // Fallback to topMostViewController for SwiftUI usage
            presentingVC = UIApplication.shared.topMostViewController()
        }
        
        if let ad = interstitialAd {
            #if DEBUG
            print("[InterstitialAd] already loaded — presenting directly.")
            #endif
            ad.present(from: presentingVC)
            return
        }
        
        guard !hasExceededErrorLimit() else {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Max retries exceeded — not loading or showing.")
            #endif
            completion()
            return
        }
        
        InterstitialAd.load(
            with: AdsConfig.interstitialAdUnitId,
            request: createAdRequest()
        ) { [weak self] ad, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    #if DEBUG
                    print("[InterstitialAd] Failed to load: \(error.localizedDescription)")
                    #endif
                    self.incrementErrorCounter()
                    self.completionHandler?()
                    return
                }
                
                self.resetErrorCounter()
                
                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                ad?.present(from: presentingVC)
            }
        }
    }
    
    /// Load the interstitial ad
    func loadAd() {
        if !AdsConfig.interstitialAdEnabled {
            return
        }
        
        guard !hasExceededErrorLimit() else {
            #if DEBUG
            print("[InterstitialAd] ⚠️ Max error attempts reached — not loading.")
            #endif
            return
        }
        
        guard interstitialAd == nil else { return }
        
        InterstitialAd.load(with: AdsConfig.interstitialAdUnitId, request: createAdRequest()) { [weak self] ad, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    #if DEBUG
                    print("[InterstitialAd] Failed to load: \(error.localizedDescription)")
                    #endif
                    self.incrementErrorCounter()
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
    func showAd(from viewController: UIViewController? = nil, onBack: Bool = false, completion: @escaping () -> Void) {
        if !AdsConfig.interstitialAdEnabled {
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
        
        guard let ad = interstitialAd else {
            loadAd()
            completion()
            return
        }
        
        if onBack {
            if displayLimitCounter < AdsConfig.maxInterstitialAdsPerSession {
                if displayCounterOnBack >= AdsConfig.interstitialAdShowCountOnBack {
                    displayCounterOnBack = 1
                    displayLimitCounter += 1
                    resetErrorCounter()
                    completionHandler = completion
                    ad.present(from: presentingVC)
                } else {
                    displayCounterOnBack += 1
                    completion()
                }
            } else {
                completion()
            }
        } else {
            if displayLimitCounter < AdsConfig.maxInterstitialAdsPerSession {
                if displayCounter >= AdsConfig.interstitialAdShowCount {
                    displayCounter = 1
                    displayLimitCounter += 1
                    resetErrorCounter()
                    completionHandler = completion
                    ad.present(from: presentingVC)
                } else {
                    displayCounter += 1
                    completion()
                }
            } else {
                completion()
            }
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
    }
    
    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        #if DEBUG
        print("[InterstitialAd] Failed to present: \(error.localizedDescription)")
        #endif
        interstitialAd = nil
        loadAd()
        completionHandler?()
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
