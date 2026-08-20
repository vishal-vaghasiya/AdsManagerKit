import GoogleMobileAds
import Foundation
import UIKit

public protocol NativeAdLoaderOutput: AnyObject {
    func nativeAdLoader(
        _ loader: InlineNativeAdManager,
        didLoad ad: NativeAd
    )

    func nativeAdLoader(
        _ loader: InlineNativeAdManager,
        didFailWith error: Error
    )
}

@MainActor
public final class InlineNativeAdManager: NSObject {

    public static let shared = InlineNativeAdManager()

    // MARK: - State

    private var targetCount: Int = 0
    private var loadedAds: [NativeAd] = []
    private var activeLoaders: [AdLoader: UUID] = [:]

    private var loadSessionID = UUID()

    private var completion: (([NativeAd]) -> Void)?
    private weak var rootViewController: UIViewController?

    private var currentNativeAdErrorCount: Int = 0
    private var lastNativeAdErrorTime: Date?

    private let nativeAdRetryCooldown: TimeInterval = 90

    public weak var output: NativeAdLoaderOutput?

    private override init() {
        super.init()
    }

    // MARK: - Public API

    public func loadNativeAds(
        count: Int,
        rootViewController: UIViewController,
        completion: @escaping ([NativeAd]) -> Void
    ) {
        guard AdsConfig.nativeAdEnabled, count > 0 else {
            completion([])
            return
        }

        self.loadSessionID = UUID()
        self.targetCount = count
        self.loadedAds = []
        self.activeLoaders.removeAll()
        self.completion = completion
        self.rootViewController = rootViewController
        self.output = rootViewController as? NativeAdLoaderOutput

        loadNextIfPossible(sessionID: loadSessionID)
    }

    // MARK: - Loading Logic

    private func loadNextIfPossible(sessionID: UUID) {
        guard sessionID == loadSessionID else {
            return
        }

        if loadedAds.count >= targetCount {
            finish()
            return
        }

        guard !hasExceededErrorLimit() else {
            finish()
            return
        }

        guard activeLoaders.isEmpty else {
            return
        }

        let loader = AdLoader(
            adUnitID: AdsConfig.nativeAdUnitId,
            rootViewController: rootViewController,
            adTypes: [.native],
            options: nil
        )

        loader.delegate = self
        activeLoaders[loader] = sessionID

        loader.load(Request())
    }

    private func resetErrorCounter() {
        currentNativeAdErrorCount = 0
        lastNativeAdErrorTime = nil
    }

    private func incrementErrorCounter() {
        currentNativeAdErrorCount += 1
        lastNativeAdErrorTime = Date()
    }

    private func hasExceededErrorLimit() -> Bool {
        if currentNativeAdErrorCount < AdsConfig.nativeAdErrorCount {
            return false
        }

        guard let lastErrorTime = lastNativeAdErrorTime else {
            return true
        }

        let canRetry = Date().timeIntervalSince(lastErrorTime) >= nativeAdRetryCooldown

        if canRetry {
            resetErrorCounter()
        }

        return !canRetry
    }

    private func finish() {
        let ads = loadedAds
        let completion = self.completion

        self.completion = nil
        self.rootViewController = nil
        self.output = nil
        self.activeLoaders.removeAll()

        completion?(ads)
    }
}

// MARK: - NativeAdLoaderDelegate

extension InlineNativeAdManager: NativeAdLoaderDelegate {

    nonisolated public func adLoader(
        _ adLoader: AdLoader,
        didReceive nativeAd: NativeAd
    ) {
        Task { @MainActor in
            guard let sessionID = self.activeLoaders.removeValue(forKey: adLoader),
                  sessionID == self.loadSessionID else {
                return
            }

            self.resetErrorCounter()
            self.loadedAds.append(nativeAd)

            self.output?.nativeAdLoader(
                self,
                didLoad: nativeAd
            )

            guard self.loadedAds.count < self.targetCount else {
                self.finish()
                return
            }

            self.loadNextIfPossible(sessionID: sessionID)
        }
    }

    @objc nonisolated public func adLoader(
        _ adLoader: AdLoader,
        didFailToReceiveAdWithError error: Error
    ) {
        Task { @MainActor in
            guard let sessionID = self.activeLoaders.removeValue(forKey: adLoader),
                  sessionID == self.loadSessionID else {
                return
            }

            self.incrementErrorCounter()

            self.output?.nativeAdLoader(
                self,
                didFailWith: error
            )

            guard self.loadedAds.count < self.targetCount else {
                self.finish()
                return
            }

            self.loadNextIfPossible(sessionID: sessionID)
        }
    }
}

extension AdLoader: @unchecked Sendable {}
