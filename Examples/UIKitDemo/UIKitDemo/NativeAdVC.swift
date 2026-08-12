import UIKit
import AdsManager

class NativeAdVC: UIViewController {
    
    @IBOutlet weak var smallNativeAdView: UIView!
    @IBOutlet weak var mediumNativeAdView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    override func viewDidAppear(_ animated: Bool) {
        AdsManager.shared.loadNative(in: smallNativeAdView, rootViewController: self, adType: .SMALL)
        AdsManager.shared.loadNative(in: mediumNativeAdView, rootViewController: self, adType: .MEDIUM)
    }
    
    @IBAction func fullScreenNativeClick(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "FullNativeAdVC") as! FullNativeAdVC
        vc.modalPresentationStyle = .overFullScreen
        self.present(vc, animated: false)
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
