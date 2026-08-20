import UIKit
import AdsManager
import GoogleMobileAds
class MainViewController: UIViewController {
    var loadedAds: [NativeAd] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        /*NativeAdLoader.shared.loadNativeAds(count: 2, rootViewController: self) { ads in
            self.loadedAds = ads
            print("Native Ad Loaded:: \(ads.count)")
        }*/
    }
    
    @IBAction func openAdButtonClick(_ sender: UIButton) {
        AppOpenAdManager.shared.tryToPresentAd()
    }
    
    @IBAction func bannerAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.showInterstitialIfAvailable()
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "BannerAdVC") as! BannerAdVC
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func interstitialAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.showInterstitialIfAvailable()
    }
    
    @IBAction func nativeAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.showInterstitialIfAvailable()
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "NativeAdVC") as! NativeAdVC
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

extension MainViewController: NativeAdLoaderOutput {
    func nativeAdLoader(_ loader: AdsManagerKit.InlineNativeAdManager, didLoad ad: NativeAd) {
        print("didLoad")
    }
    
    func nativeAdLoader(_ loader: AdsManagerKit.InlineNativeAdManager, didFailWith error: any Error) {
        print("didFailWith")
    }
}
