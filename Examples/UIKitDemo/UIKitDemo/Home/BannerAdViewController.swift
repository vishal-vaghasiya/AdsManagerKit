import UIKit
import AdsManager
import GoogleMobileAds
class BannerAdViewController: UIViewController, BannerViewDelegate {
    @IBOutlet weak var bannerView: UIView!
    @IBOutlet weak var conBannerHeight: NSLayoutConstraint!
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AdsManager.shared.loadBannerAd(in: bannerView, rootViewController: self, type: .collapsed(position: .bottom)) { isLoaded, height in
            self.conBannerHeight.constant = height
        }
    }

}
