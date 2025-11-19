//
//  NativeAdVC.swift
//  UIKitDemo
//
//  Created by Nexios Technologies on 19/11/25.
//

import UIKit
import AdsManager

class NativeAdVC: UIViewController {
    
    @IBOutlet weak var smallNativeAdView: UIView!
    @IBOutlet weak var mediumNativeAdView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AdsManager.shared.loadNative(in: smallNativeAdView, adType: .SMALL)
        AdsManager.shared.loadNative(in: mediumNativeAdView, adType: .MEDIUM)
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
