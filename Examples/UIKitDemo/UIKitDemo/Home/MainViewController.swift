import UIKit
import AdsManager
import GoogleMobileAds
class MainViewController: UIViewController {
    var loadedAds: [NativeAd] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func bannerAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.showInterstitialIfAvailable()
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "BannerAdViewController") as! BannerAdViewController
        self.navigationController?.pushViewController(vc, animated: true)
    }
   
    @IBAction func nativeAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.showInterstitialIfAvailable()
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "NativeAdViewController") as! NativeAdViewController
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
