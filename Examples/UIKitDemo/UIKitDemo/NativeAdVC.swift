import UIKit
import AdsManager
import GoogleMobileAds
class NativeAdVC: UIViewController {
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var conContainerViewHeight: NSLayoutConstraint!
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    override func viewDidAppear(_ animated: Bool) {
        guard let adView = Bundle.main.loadNibNamed("NativeAdView", owner: nil, options: nil)?.first as? NativeAdView else {
            return
        }
        
        AdsManager.shared.loadNativeAd(
            in: containerView,
            rootViewController: self,
            adView: adView,
            height: 350) { isLoaded, height in
                self.conContainerViewHeight.constant = height
            }
    }
    
    @IBAction func inlineNativeClick(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "FeedViewController") as! FeedViewController
        vc.modalPresentationStyle = .overFullScreen
        self.present(vc, animated: false)
    }
    
}
