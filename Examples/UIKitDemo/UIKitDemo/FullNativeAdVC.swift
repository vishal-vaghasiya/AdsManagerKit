import UIKit
import AdsManager

class FullNativeAdVC: UIViewController {

    @IBOutlet weak var brnClose: UIButton!
    @IBOutlet weak var nativeAdView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        AdsManager.shared.loadNative(in: nativeAdView, rootViewController: self, adType: .LARGE)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
            self.brnClose.isHidden = false
        })
    }
    
    @IBAction func closeButtonClick(_ sender: UIButton) {
        self.dismiss(animated: false)
    }

}
