import UIKit
import AdsManagerKit

class SplashViewController: UIViewController, AppOpenAdManagerDelegate {
    // MARK: - OUTLET
    @IBOutlet weak var splashScreenLabel: UILabel!
    
    // MARK: - PROPERTY
    
    // MARK: - LIFE CYCLE
    override func viewDidLoad() {
        super.viewDidLoad()
        AppOpenAdManager.shared.delegate = self
        setupSplash()
        setupAds()
    }
    
    // MARK: - UI SETUP
    private func setupSplash() {
        AdsManager.configureAds(isProduction: false,
                                openAdEnabled: true,
                                openAdOnSplashEnabled: false,
                                bannerAdEnabled: true,
                                interstitialAdEnabled: true,
                                showInterstitialLoadingIndicator: true,
                                nativeAdEnabled: true,
                                interstitialAdShowCount: 4,
                                maxInterstitialAdsPerSession: 5,
                                bannerAdErrorCount: 7,
                                interstitialAdErrorCount: 7,
                                nativeAdErrorCount: 7)
    }
    
    private func setupAds() {
        AdsManager.configure { [weak self] in
            guard self != nil else { return }
            AppOpenAdManager.shared.tryToPresentSplashAd()
        }
    }
    
    private func startMainScreen() {
        AppOpenAdManager.shared.delegate = nil
        
        let mainStoryBoard = UIStoryboard(name: "Main", bundle: nil)
        let navigationController = mainStoryBoard.instantiateViewController(
            withIdentifier: "NavigationController")
        present(navigationController, animated: true) {
            self.dismiss(animated: false) {
                // Find the keyWindow which is currently being displayed on the device,
                // and set its rootViewController to mainViewController.
                let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
                keyWindow?.rootViewController = navigationController
            }
        }
    }
    
    // MARK: - BUTTON CLICK
    
    // MARK: - OTHER
    
    // MARK: - DELEGATE
    func appOpenAdManagerDidComplete(_ manager: AdsManagerKit.AppOpenAdManager) {
        startMainScreen()
    }
}
