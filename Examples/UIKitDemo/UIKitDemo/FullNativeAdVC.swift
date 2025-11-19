//
//  FullNativeAdVC.swift
//  UIKitDemo
//
//  Created by Nexios Technologies on 19/11/25.
//

import UIKit
import AdsManager

class FullNativeAdVC: UIViewController {

    @IBOutlet weak var nativeAdView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        AdsManager.shared.loadNative(in: nativeAdView, adType: .LARGE)
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
