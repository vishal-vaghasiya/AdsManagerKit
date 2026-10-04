import GoogleMobileAds
import SwiftUI
import UIKit

public enum BannerAdType: Hashable, Sendable {
    case regular
    case large
    case adaptive
    case collapsed(position: CollapsedPosition)

    public enum CollapsedPosition: String, Hashable, Sendable {
        case top
        case bottom
    }
}

@MainActor
final class BannerAdManager: NSObject {
    
    static let shared = BannerAdManager()
    
    private struct BannerSession {
        let completion: (Bool, CGFloat) -> Void
        let expectedHeight: CGFloat
        weak var shimmerView: AdShimmerView?
    }
    
    private var activeSessions: [ObjectIdentifier: BannerSession] = [:]
    private(set) var bannerHeight: CGFloat = 0
    
    private var lastBannerAdErrorTime: Date?
    private let bannerAdRetryCooldown: TimeInterval = 60

    public func resetErrorCounter() {
        AdsConfig.currentBannerAdErrorCount = 0
        lastBannerAdErrorTime = nil
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
        }

        return !canRetry
    }
    
    /// Cleans up a specific banner view and its loading session.
    func cleanupBanner(_ banner: BannerView) {
        banner.delegate = nil
        if let session = activeSessions.removeValue(forKey: ObjectIdentifier(banner)) {
            session.shimmerView?.remove()
        }
        banner.removeFromSuperview()
    }

    /// Removes any banner views previously added to the specified container view.
    /// Does NOT affect banner views in other containers.
    func removeBanner(from containerView: UIView) {
        for subview in containerView.subviews {
            if let banner = subview as? BannerView {
                cleanupBanner(banner)
            }
        }
    }

    @discardableResult
    func loadBannerAd(
        in containerView: UIView,
        vc: UIViewController,
        type: BannerAdType,
        completion: @escaping (Bool, CGFloat) -> Void
    ) -> BannerView? {
        guard AdsConfig.isBannerAdEnabled else {
            completion(false, 0)
            return nil
        }

        guard !hasExceededErrorLimit() else {
            #if DEBUG
            print("[BannerAd] ⚠️ Max retries exceeded — not loading or showing.")
            #endif
            completion(false, 0)
            return nil
        }

        containerView.layoutIfNeeded()

        let viewWidth = containerView.bounds.width

        guard viewWidth > 0 else {
            completion(false, 0)
            return nil
        }

        let adSize: AdSize

        switch type {
        case .regular:
            adSize = AdSizeBanner

        case .large:
            adSize = AdSizeLargeBanner

        case .adaptive:
            adSize = largeAnchoredAdaptiveBanner(width: viewWidth)
            
        case .collapsed:
            adSize = currentOrientationAnchoredAdaptiveBanner(
                width: viewWidth
            )
        }

        let currentBannerHeight = adSize.size.height
        bannerHeight = currentBannerHeight

        // Clean up previous banner from THIS container only
        removeBanner(from: containerView)

        // Show shimmer while banner is loading
        let shimmerView = AdShimmerView()
        shimmerView.show(
            in: containerView,
            height: currentBannerHeight
        )

        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdsConfig.bannerAdUnitID
        banner.rootViewController = vc
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(banner)
        containerView.clipsToBounds = true

        NSLayoutConstraint.activate([
            banner.bottomAnchor.constraint(
                equalTo: containerView.safeAreaLayoutGuide.bottomAnchor
            ),
            banner.centerXAnchor.constraint(
                equalTo: containerView.centerXAnchor
            )
        ])

        activeSessions[ObjectIdentifier(banner)] = BannerSession(
            completion: completion,
            expectedHeight: currentBannerHeight,
            shimmerView: shimmerView
        )

        let request = Request()

        if case let .collapsed(position) = type {
            let extras = Extras()
            extras.additionalParameters = [
                "collapsible": position.rawValue
            ]
            request.register(extras)
        }

        banner.load(request)
        return banner
    }

    // MARK: - SwiftUI Banner Container
    @discardableResult
    public func makeBannerContainer(
        in containerView: UIView,
        width: CGFloat,
        adType: BannerAdType,
        onAdLoaded: ((CGFloat) -> Void)? = nil,
        onAdStateChanged: ((Bool, CGFloat) -> Void)? = nil
    ) -> BannerView? {
        guard let rootVC = resolveViewController(for: containerView) else {
            onAdStateChanged?(false, 0)
            return nil
        }

        return loadBannerAd(
            in: containerView,
            vc: rootVC,
            type: adType
        ) { success, height in
            let resolvedHeight = success ? height : 0
            onAdStateChanged?(success, resolvedHeight)
            if success {
                onAdLoaded?(resolvedHeight)
            }
        }
    }

    private func resolveViewController(for view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let vc = current as? UIViewController {
                return vc
            }
            responder = current.next
        }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        let window = activeScene?.windows.first(where: { $0.isKeyWindow }) ?? activeScene?.windows.first
        return window?.rootViewController
    }
}

extension BannerAdManager: BannerViewDelegate {
    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        #if DEBUG
        print("[BannerAd] loaded.")
        #endif

        resetErrorCounter()

        guard let session = activeSessions.removeValue(forKey: ObjectIdentifier(bannerView)) else {
            return
        }

        session.shimmerView?.remove()
        let height = bannerView.adSize.size.height > 0 ? bannerView.adSize.size.height : session.expectedHeight
        self.bannerHeight = height
        session.completion(true, height)
    }
    
    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        #if DEBUG
        print("[BannerAd] Failed to load: \(error.localizedDescription)")
        #endif
        
        incrementErrorCounter()
        
        guard let session = activeSessions.removeValue(forKey: ObjectIdentifier(bannerView)) else {
            return
        }

        session.shimmerView?.remove()
        session.completion(false, 0)
    }
}

// MARK: - SwiftUI Banner Wrapper
public struct BannerAdView: UIViewRepresentable {

    public var adType: BannerAdType
    public var onAdLoaded: ((CGFloat) -> Void)?

    @Binding private var isLoaded: Bool
    @Binding private var height: CGFloat

    public init(
        adType: BannerAdType,
        isLoaded: Binding<Bool> = .constant(false),
        height: Binding<CGFloat> = .constant(0),
        onAdLoaded: ((CGFloat) -> Void)? = nil
    ) {
        self.adType = adType
        self._isLoaded = isLoaded
        self._height = height
        self.onAdLoaded = onAdLoaded
    }

    public func makeUIView(context: Context) -> BannerContainerView {
        let containerView = BannerContainerView()
        containerView.adType = adType

        containerView.onAdStateChanged = { loaded, resolvedHeight in
            DispatchQueue.main.async {
                self.isLoaded = loaded
                self.height = resolvedHeight
            }
        }

        containerView.onAdLoaded = { loadedHeight in
            self.onAdLoaded?(loadedHeight)
        }

        return containerView
    }

    public func updateUIView(
        _ uiView: BannerContainerView,
        context: Context
    ) {
        uiView.onAdStateChanged = { loaded, resolvedHeight in
            DispatchQueue.main.async {
                self.isLoaded = loaded
                self.height = resolvedHeight
            }
        }
        uiView.onAdLoaded = { loadedHeight in
            self.onAdLoaded?(loadedHeight)
        }

        if uiView.adType != adType {
            uiView.adType = adType
            uiView.reloadBanner()
        }
    }
}

@MainActor
public final class BannerContainerView: UIView {
    public var adType: BannerAdType = .regular
    public var onAdLoaded: ((CGFloat) -> Void)?
    public var onAdStateChanged: ((Bool, CGFloat) -> Void)?

    private var didStartLoading = false
    private(set) var bannerView: BannerView?
    private var lastLoadAttempt: Date?
    private let retryCooldown: TimeInterval = 30

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }

        if bannerView == nil && !didStartLoading {
            loadAdIfNeeded()
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && bannerView == nil && !didStartLoading && bounds.width > 0 {
            loadAdIfNeeded()
        }
    }

    public func loadAdIfNeeded() {
        guard bannerView == nil, !didStartLoading, bounds.width > 0 else { return }

        if let last = lastLoadAttempt, Date().timeIntervalSince(last) < retryCooldown {
            return
        }

        didStartLoading = true
        lastLoadAttempt = Date()

        self.bannerView = BannerAdManager.shared.makeBannerContainer(
            in: self,
            width: bounds.width,
            adType: adType,
            onAdLoaded: { [weak self] loadedHeight in
                guard let self else { return }
                self.didStartLoading = false
                self.onAdLoaded?(loadedHeight)
            },
            onAdStateChanged: { [weak self] loaded, resolvedHeight in
                guard let self else { return }
                self.didStartLoading = false
                if !loaded {
                    self.bannerView = nil
                }
                self.onAdStateChanged?(loaded, resolvedHeight)
            }
        )
    }

    public func reloadBanner() {
        didStartLoading = false
        lastLoadAttempt = nil
        let previousBanner = bannerView
        bannerView = nil
        if let previousBanner {
            BannerAdManager.shared.cleanupBanner(previousBanner)
        } else {
            BannerAdManager.shared.removeBanner(from: self)
        }
        if bounds.width > 0 {
            loadAdIfNeeded()
        }
    }

    deinit {
        let banner = bannerView
        if let banner {
            Task { @MainActor in
                BannerAdManager.shared.cleanupBanner(banner)
            }
        }
    }
}
