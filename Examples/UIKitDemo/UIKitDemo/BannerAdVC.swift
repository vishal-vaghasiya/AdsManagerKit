import UIKit
import AdsManager

class BannerAdVC: UIViewController {

    @IBOutlet weak var regularBannerView: UIView!
    
    @IBOutlet weak var largeBannerView: UIView!
    @IBOutlet weak var conLargeBannerHeight: NSLayoutConstraint!
    
    @IBOutlet weak var adaptiveBannerView: UIView!
    @IBOutlet weak var conAdaptiveBannerHeight: NSLayoutConstraint!
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        /*AdsManager.shared.loadBanner(in: regularBannerView, rootViewController: self, type: .regular) { isLoaded, height in
            print("regular: \(isLoaded) - \(height)")
        }*/
        
        /*AdsManager.shared.loadBanner(in: largeBannerView, rootViewController: self, type: .large) { isLoaded, height in
            self.conLargeBannerHeight.constant = height
            print("largeAdaptive: \(isLoaded) - \(height)")
        }*/
        
        AdsManager.shared.loadBanner(in: adaptiveBannerView, rootViewController: self, type: .largeAdaptive) { isLoaded, height in
            self.conAdaptiveBannerHeight.constant = height
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
