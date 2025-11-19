//
//  BannerAdVC.swift
//  UIKitDemo
//
//  Created by Nexios Technologies on 19/11/25.
//

import UIKit
import AdsManager

class BannerAdVC: UIViewController {

    @IBOutlet weak var regularBannerView: UIView!
    @IBOutlet weak var adaptiveBannerView: UIView!
    @IBOutlet weak var conAdaptiveBannerHeight: NSLayoutConstraint!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AdsManager.shared.loadBanner(in: regularBannerView, rootViewController: self, type: .REGULAR) { _, _ in }
        
        AdsManager.shared.loadBanner(in: adaptiveBannerView, rootViewController: self, type: .ADAPTIVE) { _, height in
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
