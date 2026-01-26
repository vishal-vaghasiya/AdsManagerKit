import GoogleMobileAds
import SwiftUI
import UIKit
public enum BannerAdType: String {
    case ADAPTIVE
    case REGULAR
}

@MainActor
final class BannerAdManager: NSObject {
    
    static let shared = BannerAdManager()
    
    private var bannerView: BannerView?
    private var completionHandler: ((Bool, CGFloat) -> Void)?
    private var bannerHeight = CGFloat(0)
    
    public func resetErrorCounter() {
        AdsConfig.currentBannerAdErrorCount = 0
    }
    
    private func incrementErrorCounter() {
        AdsConfig.currentBannerAdErrorCount += 1
    }
    
    private func hasExceededErrorLimit() -> Bool {
        return AdsConfig.currentBannerAdErrorCount >= AdsConfig.bannerAdErrorCount
    }
    
    func loadBannerAd(in containerView: UIView,
                      vc: UIViewController,
                      type: BannerAdType,
                      completion: @escaping (Bool, CGFloat) -> Void) {
        guard AdsConfig.bannerAdEnabled else {
            completion(false, 0)
            return
        }

        guard !hasExceededErrorLimit() else {
            #if DEBUG
            print("[BannerAd] ⚠️ Max retries exceeded — not loading or showing.")
            #endif
            completion(false, 0)
            return
        }

        let viewWidth = containerView.bounds.width > 0 ? containerView.bounds.width : UIScreen.main.bounds.width
        var adSize: AdSize
        if type == .ADAPTIVE {
            adSize = currentOrientationAnchoredAdaptiveBanner(width: viewWidth)
            bannerHeight = adSize.size.height
        } else {
            adSize = AdSize(size: CGSize(width: 320, height: 50), flags: 0)
            bannerHeight = adSize.size.height
        }

        let banner = BannerView(adSize: adSize)
        bannerView = banner
        banner.adUnitID = AdsConfig.bannerAdUnitId
        banner.rootViewController = vc
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(banner)
        containerView.clipsToBounds = true

        NSLayoutConstraint.activate([
            banner.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor),
            banner.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])

        // Use consent-aware request
        let request = createAdRequest()
        banner.load(request)
        self.completionHandler = completion
    }

    private func createAdRequest() -> Request {
        return Request() // Latest UMP SDK automatically handles ATT/GDPR
    }
    
    /// SwiftUI-friendly banner container
    public func makeBannerContainer(adType: BannerAdType = .REGULAR,
                                    onAdLoaded: ((CGFloat) -> Void)? = nil) -> UIView {
        let containerView = UIView()
        
        guard let rootVC = UIApplication.shared.windows.first?.rootViewController else {
            return containerView
        }
        
        // Call existing loadBannerAd, but forward a SwiftUI callback separately
        loadBannerAd(in: containerView, vc: rootVC, type: adType) { success, height in
            DispatchQueue.main.async {
                containerView.frame.size.height = height
                onAdLoaded?(height)
            }
        }
        
        return containerView
    }
    
}

extension BannerAdManager: BannerViewDelegate {
    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        #if DEBUG
        print("[BannerAd] loaded.")
        #endif
        self.resetErrorCounter()
        completionHandler?(true, bannerHeight)
    }
    
    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        #if DEBUG
        print("[BannerAd] Failed to load: \(error.localizedDescription)")
        #endif
        self.incrementErrorCounter()
        completionHandler?(false, 0)
    }
}

// MARK: - SwiftUI Banner Wrapper
public struct BannerAdView: UIViewRepresentable {
    public var adType: BannerAdType = .REGULAR
    public var onAdLoaded: ((CGFloat) -> Void)? = nil

    public init(adType: BannerAdType = .REGULAR,
                onAdLoaded: ((CGFloat) -> Void)? = nil) {
        self.adType = adType
        self.onAdLoaded = onAdLoaded
    }

    public func makeUIView(context: Context) -> UIView {
        BannerAdManager.shared.makeBannerContainer(adType: adType, onAdLoaded: onAdLoaded)
    }

    public func updateUIView(_ uiView: UIView, context: Context) { }
}
