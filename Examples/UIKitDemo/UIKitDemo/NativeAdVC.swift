//
//  NativeAdVC.swift
//  UIKitDemo
//
//  Created by VISHAL VAGHASIYA on 19/11/25.
//

import UIKit
import AdsManager

class NativeAdVC: UIViewController {
    
    @IBOutlet weak var smallNativeAdView: UIView!
    @IBOutlet weak var mediumNativeAdView: UIView!
    @IBOutlet weak var largeNativeAdView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AdsManager.shared.loadNative(in: smallNativeAdView, rootViewController: self, adType: .SMALL)
        AdsManager.shared.loadNative(in: mediumNativeAdView, rootViewController: self, adType: .MEDIUM)
        AdsManager.shared.loadNative(in: largeNativeAdView, rootViewController: self, adType: .LARGE)
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
