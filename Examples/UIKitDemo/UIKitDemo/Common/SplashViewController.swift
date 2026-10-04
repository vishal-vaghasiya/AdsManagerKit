import UIKit
import AdsManagerKit

class SplashViewController: UIViewController, AppOpenAdDelegate {
    
    // MARK: - OUTLET
    @IBOutlet weak var splashScreenLabel: UILabel!
    
    // MARK: - PROPERTY
    
    // MARK: - LIFE CYCLE
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSetup()
    }
    
    // MARK: - UI SETUP
    private func configureSetup() {
        let configuration = AppConfigurationLoader.load()
        AdsManager.initialize(with: configuration) { [weak self] in
            guard self != nil else {
                self?.startMainScreen()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + AdsConfig.splashDelaySeconds, execute: {
                AdsManager.shared.tryToPresentSplashAd(delegate: self)
            })
        }
    }
    
    private func startMainScreen() {
        let mainStoryBoard = UIStoryboard(name: "Main", bundle: nil)
        let navigationController = mainStoryBoard.instantiateViewController(withIdentifier: "NavigationController")
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
