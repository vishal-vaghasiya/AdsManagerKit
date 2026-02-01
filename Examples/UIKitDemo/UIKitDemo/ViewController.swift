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
                                bannerAdEnabled: true,
                                interstitialAdEnabled: true,
                                nativeAdEnabled: true,
                                interstitialAdShowCount: 4,
                                maxInterstitialAdsPerSession: 5,
                                bannerAdErrorCount: 7,
                                interstitialAdErrorCount: 7,
                                nativeAdErrorCount: 7)
        
        AdsManager.configure()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        /*NativeAdLoader.shared.loadNativeAds(count: 2, rootViewController: self) { ads in
            self.loadedAds = ads
            print("Native Ad Loaded:: \(ads.count)")
        }*/
    }
    
    @IBAction func openAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.presentAppOpenAdIfAvailable()
    }
    
    @IBAction func bannerAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.showInterstitialIfAvailable()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "BannerAdVC") as! BannerAdVC
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func interstitialAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.showInterstitialIfAvailable()
    }
    
    @IBAction func nativeAdButtonClick(_ sender: UIButton) {
        AdsManager.shared.showInterstitialIfAvailable()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "NativeAdVC") as! NativeAdVC
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

extension ViewController: NativeAdLoaderOutput {
    func nativeAdLoader(_ loader: NativeAdLoader, didLoad ad: NativeAd) {
        print("didLoad")
    }
    
    func nativeAdLoader(_ loader: NativeAdLoader, didFailWith error: any Error) {
        print("didFailWith")
    }
}
