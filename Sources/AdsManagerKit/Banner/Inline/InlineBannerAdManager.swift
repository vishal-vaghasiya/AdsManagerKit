import GoogleMobileAds
import UIKit

@MainActor
public final class InlineBannerAdManager: NSObject {

    // MARK: - Properties

    public private(set) var bannerView: BannerView?

    public private(set) var isLoaded: Bool = false
    public private(set) var isLoading: Bool = false
    public private(set) var bannerHeight: CGFloat = 0

    public var onAdStateChanged: ((Bool, CGFloat) -> Void)?

    private weak var rootViewController: UIViewController?

    private var currentWidth: CGFloat = 0

    // MARK: - Initialization

    public init(
        rootViewController: UIViewController,
        width: CGFloat
    ) {
        self.rootViewController = rootViewController
        self.currentWidth = width

        super.init()
        configureBanner()
    }

    // MARK: - Public Methods

    /// Loads the inline adaptive banner.
    public func load() {

        guard AdsConfig.bannerAdEnabled else {
            notifyAdState(
                loaded: false,
                height: 0
            )
            return
        }

        guard !isLoading, !isLoaded else {
            return
        }

        guard currentWidth > 0 else {
            #if DEBUG
            print("[InlineBannerAd] Invalid width.")
            #endif

            notifyAdState(
                loaded: false,
                height: 0
            )

            return
        }

        guard let bannerView else {
            configureBanner()
            load()
            return
        }

        isLoading = true

        bannerView.load(Request())

        #if DEBUG
        print("[InlineBannerAd] Loading...")
        #endif
    }

    /// Updates the banner width.
    ///
    /// Call this when the table/container width changes,
    /// for example after device rotation or iPad split-screen changes.
    public func updateWidth(_ width: CGFloat) {

        guard width > 0 else {
            return
        }

        guard abs(currentWidth - width) > 0.5 else {
            return
        }

        currentWidth = width

        let newAdSize = Self.adaptiveAdSize(
            width: width
        )

        bannerHeight = newAdSize.size.height

        guard let bannerView else {
            configureBanner()
            return
        }

        let oldSize = bannerView.adSize.size

        guard oldSize != newAdSize.size else {
            return
        }

        isLoaded = false
        isLoading = false

        bannerView.adSize = newAdSize

        #if DEBUG
        print(
            "[InlineBannerAd] Width updated: \(width), " +
            "height: \(newAdSize.size.height)"
        )
        #endif
    }

    /// Reloads the banner.
    public func reload() {

        guard AdsConfig.bannerAdEnabled else {
            notifyAdState(
                loaded: false,
                height: 0
            )

            return
        }

        isLoaded = false
        isLoading = false

        bannerView?.load(Request())

        isLoading = true

        #if DEBUG
        print("[InlineBannerAd] Reloading...")
        #endif
    }

    /// Removes the banner and resets its state.
    public func reset() {

        bannerView?.delegate = nil
        bannerView?.removeFromSuperview()

        bannerView = nil

        isLoaded = false
        isLoading = false
        bannerHeight = 0

        #if DEBUG
        print("[InlineBannerAd] Reset.")
        #endif
    }

    // MARK: - Private Methods

    private func configureBanner() {
        guard currentWidth > 0 else {
            return
        }

        let adSize = Self.adaptiveAdSize(
            width: currentWidth
        )

        bannerHeight = adSize.size.height

        let banner = BannerView(
            adSize: adSize
        )

        banner.adUnitID = AdsConfig.bannerAdUnitId
        banner.rootViewController = rootViewController
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false

        bannerView = banner

        #if DEBUG
        print(
            "[InlineBannerAd] Configured. " +
            "Width: \(currentWidth), " +
            "Height: \(bannerHeight)"
        )
        #endif
    }

    private func notifyAdState(
        loaded: Bool,
        height: CGFloat
    ) {

        isLoaded = loaded
        isLoading = false
        bannerHeight = height

        onAdStateChanged?(
            loaded,
            height
        )
    }

    private static func adaptiveAdSize(
        width: CGFloat
    ) -> AdSize {

        currentOrientationInlineAdaptiveBanner(
            width: width
        )
    }
}

// MARK: - BannerViewDelegate

extension InlineBannerAdManager: BannerViewDelegate {

    public func bannerViewDidReceiveAd(
        _ bannerView: BannerView
    ) {

        #if DEBUG
        print("[InlineBannerAd] Loaded.")
        #endif

        AdsConfig.currentBannerAdErrorCount = 0

        notifyAdState(
            loaded: true,
            height: bannerView.adSize.size.height
        )
    }

    public func bannerView(
        _ bannerView: BannerView,
        didFailToReceiveAdWithError error: Error
    ) {

        #if DEBUG
        print(
            "[InlineBannerAd] Failed to load: " +
            "\(error.localizedDescription)"
        )
        #endif

        AdsConfig.currentBannerAdErrorCount += 1

        notifyAdState(
            loaded: false,
            height: 0
        )
    }
}
