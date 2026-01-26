import Foundation
import UIKit

public struct AdsConfig {

    // MARK: - Environment Settings
    // Controls the general ad behavior and feature toggles for the app
    static var isProduction: Bool {
        get { UserDefaults.standard.bool(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    /// Indicates whether the user has premium access (ads should be disabled).
    static var isPremiumUser: Bool {
        get { UserDefaults.standard.bool(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    // MARK: - Private Helper
    /// Centralized logic to disable ads for premium users, otherwise fetch the stored value.
    private static func adEnabled(_ key: String) -> Bool {
        if isPremiumUser { return false }
        return UserDefaults.standard.bool(forKey: key)
    }

    static var openAdEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var bannerAdEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var interstitialAdEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var nativeAdEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var nativeAdPreloadEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var openAdOnLaunchEnabled: Bool {
        get { adEnabled(#function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }
    
    // MARK: - Ad Unit Identifiers
    // Stores the AdMob unit IDs for each ad format
    static var openAdUnitId: String {
        get { isProduction ? UserDefaults.standard.string(forKey: #function) ?? "" : "ca-app-pub-3940256099942544/5575463023" }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var bannerAdUnitId: String {
        get { isProduction ? UserDefaults.standard.string(forKey: #function) ?? "" : "ca-app-pub-3940256099942544/2934735716" }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var interstitialAdUnitId: String {
        get { isProduction ? UserDefaults.standard.string(forKey: #function) ?? "" : "ca-app-pub-3940256099942544/4411468910" }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    static var nativeAdUnitId: String {
        get { isProduction ? UserDefaults.standard.string(forKey: #function) ?? "" : "ca-app-pub-3940256099942544/3986624511" }
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
    nonisolated(unsafe) static var currentBannerAdErrorCount: Int = 0
    nonisolated(unsafe) static var currentInterstitialAdErrorCount: Int = 0
    nonisolated(unsafe) static var currentNativeAdErrorCount: Int = 0
}
