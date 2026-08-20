import UIKit
import AdsManagerKit

class SplashViewController: UIViewController, AppOpenAdDelegate {
    
    // MARK: - OUTLET
    @IBOutlet weak var splashScreenLabel: UILabel!
    
    // MARK: - PROPERTY
    
    // MARK: - LIFE CYCLE
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSplash()
        setupAds()
    }
    
    // MARK: - UI SETUP
    private func setupSplash() {
        #if DEBUG
        let isProduction = false
        #else
        let isProduction = true
        #endif
        
        AdsManager.configureAds(isProduction: isProduction,
                                openAdEnabled: true,
                                openAdOnSplashEnabled: true,
                                bannerAdEnabled: true,
                                interstitialAdEnabled: false,
                                nativeAdEnabled: true,
                                nativeAdPreloadEnabled: true,
                                nativeAdPreloadCount: 1,
                                interstitialAdShowCount: 4,
                                maxInterstitialAdsPerSession: 5,
                                bannerAdErrorCount: 7,
                                interstitialAdErrorCount: 7,
                                nativeAdErrorCount: 7)
    }
    
    private func setupAds() {
        AdsManager.configure { [weak self] in
            guard self != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                AdsManager.shared.tryToPresentSplashAd(delegate: self)
            })
        }
    }
    
    private func startMainScreen() {
        let mainStoryBoard = UIStoryboard(name: "Main", bundle: nil)
        let navigationController = mainStoryBoard.instantiateViewController(
            withIdentifier: "NavigationController")
        // Find the keyWindow which is currently being displayed on the device,
        // and set its rootViewController to mainViewController.
        let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        keyWindow?.rootViewController = navigationController
    }
    
    // MARK: - BUTTON CLICK
    
    // MARK: - OTHER
    
    // MARK: - DELEGATE
    func appOpenAdDidComplete() {
        startMainScreen()
    }
}
