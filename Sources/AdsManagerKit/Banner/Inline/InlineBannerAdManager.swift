import GoogleMobileAds
import Foundation
import UIKit

// MARK: - InlineBannerAdLoaderOutput

public protocol InlineBannerAdLoaderOutput: AnyObject {

    func inlineBannerAdLoader(_ loader: InlineBannerAdManager, didLoad bannerView: BannerView, at index: Int, height: CGFloat)

    func inlineBannerAdLoader(_ loader: InlineBannerAdManager, didFailWith error: Error, at index: Int)
}

// MARK: - InlineBannerAdManager

@MainActor
public final class InlineBannerAdManager: NSObject {

    public static let shared = InlineBannerAdManager()

    // MARK: - State

    private var targetCount: Int = 0

    private var loadedBanners: [BannerView] = []

    /// Only one BannerView is loading at a time.
    private var activeLoaders: [BannerView: UUID] = [:]

    /// Maps the currently loading BannerView to its requested index.
    private var bannerIndexes: [BannerView: Int] = [:]

    /// Used to invalidate callbacks from an old loading session.
    private var loadSessionID = UUID()

    private var completion: (([BannerView]) -> Void)?

    private weak var rootViewController: UIViewController?

    private var currentWidth: CGFloat = 0

    // MARK: - Error State

    private var currentBannerAdErrorCount: Int = 0
    private var lastBannerAdErrorTime: Date?

    private let bannerAdRetryCooldown: TimeInterval = 90

    // MARK: - Delegate

    public weak var output: InlineBannerAdLoaderOutput?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Loads multiple inline adaptive banners sequentially.
    ///
    /// Only one banner request is active at a time.
    /// Each successfully loaded banner is returned immediately
    /// through `InlineBannerAdLoaderOutput`.
    public func loadBannerAds(count: Int, rootViewController: UIViewController, width: CGFloat, completion: @escaping ([BannerView]) -> Void) {
        guard AdsConfig.bannerAdEnabled, count > 0, width > 0 else {
            completion([])
            return
        }

        // Invalidate any previous loading session.
        loadSessionID = UUID()

        targetCount = count
        loadedBanners = []
        activeLoaders.removeAll()
        bannerIndexes.removeAll()

        self.completion = completion
        self.rootViewController = rootViewController
        self.currentWidth = width

        self.output = rootViewController as? InlineBannerAdLoaderOutput

        resetErrorCounter()

        loadNextIfPossible(sessionID: loadSessionID)
    }

    /// Updates the width used for newly created adaptive banners.
    public func updateWidth(_ width: CGFloat) {
        guard width > 0 else {
            return
        }
        currentWidth = width
    }

    /// Reloads the requested number of banners.
    public func reloadBannerAds(count: Int, rootViewController: UIViewController, width: CGFloat, completion: @escaping ([BannerView]) -> Void) {
        reset()
        loadBannerAds(count: count, rootViewController: rootViewController, width: width, completion: completion)
    }

    /// Cancels the current loading session and clears all state.
    public func reset() {
        // Invalidate all previous callbacks.
        loadSessionID = UUID()

        targetCount = 0

        loadedBanners.removeAll()

        activeLoaders.removeAll()
        bannerIndexes.removeAll()

        completion = nil
        rootViewController = nil
        output = nil

        currentWidth = 0

        resetErrorCounter()

        #if DEBUG
        print("[InlineBannerAd] Reset.")
        #endif
    }

    // MARK: - Loading Logic

    private func loadNextIfPossible(sessionID: UUID) {
        guard sessionID == loadSessionID else {
            return
        }

        // Requested number of ads has been loaded.
        if loadedBanners.count >= targetCount {
            finish()
            return
        }

        // Stop if the retry/error limit has been reached.
        guard !hasExceededErrorLimit() else {
            #if DEBUG
            print(
                "[InlineBannerAd] Error limit reached. " +
                "Loaded: \(loadedBanners.count)/\(targetCount)"
            )
            #endif

            finish()
            return
        }

        // Only one banner request at a time.
        guard activeLoaders.isEmpty else {
            return
        }

        guard currentWidth > 0,
              let rootViewController else {
            finish()
            return
        }

        let index = loadedBanners.count

        let adSize = Self.adaptiveAdSize(
            width: currentWidth
        )

        let bannerView = BannerView(
            adSize: adSize
        )

        bannerView.adUnitID = AdsConfig.bannerAdUnitId
        bannerView.rootViewController = rootViewController
        bannerView.delegate = self
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        activeLoaders[bannerView] = sessionID
        bannerIndexes[bannerView] = index

        #if DEBUG
        print(
            "[InlineBannerAd] Loading banner " +
            "\(index + 1)/\(targetCount). " +
            "Width: \(currentWidth), " +
            "Height: \(adSize.size.height)"
        )
        #endif

        bannerView.load(Request())
    }

    // MARK: - Error Handling
    private func resetErrorCounter() {
        currentBannerAdErrorCount = 0
        lastBannerAdErrorTime = nil
    }

    private func incrementErrorCounter() {
        currentBannerAdErrorCount += 1
        lastBannerAdErrorTime = Date()
    }

    private func hasExceededErrorLimit() -> Bool {
        if currentBannerAdErrorCount < AdsConfig.bannerAdErrorCount {
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

    // MARK: - Finish

    private func finish() {
        let banners = loadedBanners
        let completion = self.completion

        self.completion = nil
        self.rootViewController = nil
        self.output = nil

        self.activeLoaders.removeAll()
        self.bannerIndexes.removeAll()

        completion?(banners)
    }

    // MARK: - Adaptive Size

    private static func adaptiveAdSize(width: CGFloat) -> AdSize {
        currentOrientationInlineAdaptiveBanner(width: width)
    }
}

// MARK: - BannerViewDelegate

extension InlineBannerAdManager: BannerViewDelegate {

    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        Task { @MainActor in
            guard let sessionID = self.activeLoaders.removeValue(forKey: bannerView),
                  sessionID == self.loadSessionID else {
                return
            }

            let index = self.bannerIndexes.removeValue(forKey: bannerView) ?? self.loadedBanners.count
            let height = bannerView.adSize.size.height
            
            self.resetErrorCounter()

            self.loadedBanners.append(bannerView)

            AdsConfig.currentBannerAdErrorCount = 0

            #if DEBUG
            print(
                "[InlineBannerAd] Loaded banner " +
                "\(index + 1). " +
                "Height: \(height)"
            )
            #endif

            // Return the banner immediately.
            self.output?.inlineBannerAdLoader(self, didLoad: bannerView, at: index, height: height)

            // Check if all requested banners are loaded.
            guard self.loadedBanners.count < self.targetCount else {
                self.finish()
                return
            }

            // Start loading the next banner.
            self.loadNextIfPossible(
                sessionID: sessionID
            )
        }
    }

    public func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            guard let sessionID = self.activeLoaders.removeValue(forKey: bannerView),sessionID == self.loadSessionID else {
                return
            }

            let index = self.bannerIndexes.removeValue(forKey: bannerView) ?? self.loadedBanners.count
            self.incrementErrorCounter()
            AdsConfig.currentBannerAdErrorCount += 1

            #if DEBUG
            print(
                "[InlineBannerAd] Failed banner " +
                "\(index + 1): " +
                "\(error.localizedDescription)"
            )
            #endif

            // Notify the consumer immediately.
            self.output?.inlineBannerAdLoader(self, didFailWith: error, at: index)

            // Continue loading the next banner.
            guard self.loadedBanners.count < self.targetCount else {
                self.finish()
                return
            }

            self.loadNextIfPossible(
                sessionID: sessionID
            )
        }
    }
}

// MARK: - Sendable

extension BannerView: @unchecked Sendable {}
