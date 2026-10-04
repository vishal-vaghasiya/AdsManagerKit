import Foundation
import UIKit

public struct AdsConfig {

    // MARK: - Environment Settings
    
    /// Indicates whether the user has premium access (ads should be disabled).
    static var isPremiumUser: Bool {
        get { UserDefaults.standard.bool(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    // MARK: - Private Helper
    /// Centralized logic to disable ads for premium users, otherwise fetch the stored value.
    static func adEnabled(_ key: String) -> Bool {
        if isPremiumUser { return false }
        return UserDefaults.standard.bool(forKey: key)
    }

    static var isOpenAdEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    public static var splashDelaySeconds: TimeInterval {
        get {
            guard isOpenAdOnSplashEnabled else {
                return 0
            }

            return UserDefaults.standard.double(
                forKey: #function
            )
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: #function
            )
        }
    }

    static var isOpenAdOnSplashEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var isBannerAdEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var isInterstitialAdEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    static var isNativeAdEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    static var isNativeAdPreloadEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var nativeAdPreloadCount: Int {
        get { UserDefaults.standard.object(forKey: #function) as? Int ?? 2 }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    // MARK: - Ad Unit Identifiers
    // Stores the AdMob unit IDs for each ad format
    static var openAdUnitID: String {
        get { UserDefaults.standard.string(forKey: #function) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var bannerAdUnitID: String {
        get { UserDefaults.standard.string(forKey: #function) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var interstitialAdUnitID: String {
        get { UserDefaults.standard.string(forKey: #function) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var nativeAdUnitID: String {
        get { UserDefaults.standard.string(forKey: #function) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    // MARK: - Persistent Ad Error Counters
    // Tracks total errors across app launches for banners, interstitials, and native ads
    static var bannerAdErrorCount: Int {
        get { UserDefaults.standard.integer(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    static var interstitialAdErrorCount: Int {
        get { UserDefaults.standard.integer(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    static var nativeAdErrorCount: Int {
        get { UserDefaults.standard.integer(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    // MARK: - Interstitial Ad Session Counters
    // Tracks interstitial ad display counts for session limits
    static var interstitialAdShowCount: Int {
        get { UserDefaults.standard.integer(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    static var maxInterstitialAdsPerSession: Int {
        get { UserDefaults.standard.integer(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    // MARK: - Current Session Ad Error Counters
    // Resets on each app launch; used to track errors during the current session
    nonisolated(unsafe)
    static var currentBannerAdErrorCount: Int = 0
    
    nonisolated(unsafe)
    static var currentInterstitialAdErrorCount: Int = 0
    
    nonisolated(unsafe)
    static var currentNativeAdErrorCount: Int = 0
}
