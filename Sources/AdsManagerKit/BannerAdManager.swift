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
    
    private var lastBannerAdErrorTime: Date?
    private let bannerAdRetryCooldown: TimeInterval = 60
    
    private var refreshTimer: Timer?
    private let bannerRefreshInterval: TimeInterval = 60 // seconds

    private var isRefreshPausedByBackground: Bool = false

    private var lastBannerType: BannerAdType = .ADAPTIVE

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    deinit {
        stopBannerRefresh()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appDidEnterBackground() {
        if refreshTimer != nil {
            isRefreshPausedByBackground = true
            stopBannerRefresh()
        }
    }

    @objc private func appWillEnterForeground() {
        guard isRefreshPausedByBackground,
              let bannerView = bannerView,
              let container = bannerView.superview,
              let vc = bannerView.rootViewController
        else { return }

        isRefreshPausedByBackground = false
        startBannerRefresh(in: container, vc: vc, type: lastBannerType)
    }

    public func resetErrorCounter() {
        AdsConfig.currentBannerAdErrorCount = 0
        lastBannerAdErrorTime = nil
        // keep refresh running on success
    }
    
    private func incrementErrorCounter() {
        AdsConfig.currentBannerAdErrorCount += 1
        lastBannerAdErrorTime = Date()
    }
    
    private func hasExceededErrorLimit() -> Bool {
        if AdsConfig.currentBannerAdErrorCount < AdsConfig.bannerAdErrorCount {
            return false
        }

        guard let lastErrorTime = lastBannerAdErrorTime else {
            return true
        }

        let canRetry = Date().timeIntervalSince(lastErrorTime) >= bannerAdRetryCooldown
        if canRetry {
            resetErrorCounter()
            // retry allowed, refresh will resume on next load
        }

        return !canRetry
    }
    
    private func startBannerRefresh(
        in containerView: UIView,
        vc: UIViewController,
        type: BannerAdType
    ) {
        stopBannerRefresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: bannerRefreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.loadBannerAd(
                in: containerView,
                vc: vc,
                type: type
            ) { _, _ in }
        }
    }

    nonisolated private func stopBannerRefresh() {
        Task { @MainActor in
            self.refreshTimer?.invalidate()
            self.refreshTimer = nil
        }
    }
    
    func loadBannerAd(in containerView: UIView,
                      vc: UIViewController,
                      type: BannerAdType,
                      completion: @escaping (Bool, CGFloat) -> Void) {
        guard AdsConfig.bannerAdEnabled else {
            completion(false, 0)
            return
        }
        guard completionHandler == nil else {
            #if DEBUG
            print("[BannerAd] ⛔️ Banner load already in progress. Ignoring duplicate request.")
            #endif
            return
        }

        guard !hasExceededErrorLimit() else {
            #if DEBUG
            print("[BannerAd] ⚠️ Max retries exceeded — not loading or showing.")
            #endif
            completion(false, 0)
            return
        }

        if let existingBanner = bannerView {
            existingBanner.removeFromSuperview()
            existingBanner.delegate = nil
            bannerView = nil
        }

        self.lastBannerType = type

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
        
        guard let rootVC = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
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
    
    public func stop() {
        stopBannerRefresh()
        if let banner = bannerView {
            banner.removeFromSuperview()
            banner.delegate = nil
            bannerView = nil
        }
    }
    
}

extension BannerAdManager: BannerViewDelegate {
    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        #if DEBUG
        print("[BannerAd] loaded.")
        #endif
        self.resetErrorCounter()
        startBannerRefresh(in: bannerView.superview!, vc: bannerView.rootViewController!, type: lastBannerType)
        completionHandler?(true, bannerHeight)
        completionHandler = nil
    }
    
    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        #if DEBUG
        print("[BannerAd] Failed to load: \(error.localizedDescription)")
        #endif
        self.incrementErrorCounter()
        stopBannerRefresh()
        completionHandler?(false, 0)
        completionHandler = nil
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
