//
//  ViewController.swift
//  UIKitDemo
//

import UIKit
import AdsManager
import GoogleMobileAds
class ViewController: UIViewController {
    var loadedAds: [NativeAd] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        AdsManager.configureAds(isProduction: false,
                                openAdEnabled: true,
                                openAdOnLaunchEnabled: true,
                                bannerAdEnabled: true,
                                interstitialAdEnabled: true,
                                nativeAdEnabled: true,
                                nativeAdPreloadEnabled: true,
                                interstitialAdShowCount: 1,
                                maxInterstitialAdsPerSession: 50,
                                bannerAdErrorCount: 7,
                                interstitialAdErrorCount: 7,
                                nativeAdErrorCount: 7)
        
        AdsManager.shared.loadOpenAd()
        
        NativeAdLoader.shared.loadNativeAds(count: 2) { ads in
            self.loadedAds = ads
            print("Native Ad Loaded:: \(ads.count)")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    @IBAction func openAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.presentAppOpenAdIfAvailable()
    }
    
    @IBAction func bannerAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.showInterstitial(from: self) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "BannerAdVC") as! BannerAdVC
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @IBAction func interstitialAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.showInterstitial(from: self) {
            
        }
    }
    
    @IBAction func nativeAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.showInterstitial(from: self) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "NativeAdVC") as! NativeAdVC
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

