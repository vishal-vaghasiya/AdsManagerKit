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
    private var onAdLoadedHandler: ((NativeAd, Int) -> Void)?
    private var onAdFailedHandler: ((Int, Error) -> Void)?

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
        onAdLoaded: ((NativeAd, Int) -> Void)? = nil,
        onAdFailed: ((Int, Error) -> Void)? = nil,
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
        self.onAdLoadedHandler = onAdLoaded
        self.onAdFailedHandler = onAdFailed
        self.rootViewController = rootViewController

        if self.output == nil {
            self.output = rootViewController as? NativeAdLoaderOutput
        }

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
        self.onAdLoadedHandler = nil
        self.onAdFailedHandler = nil
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

            let index = self.loadedAds.count
            self.resetErrorCounter()
            self.loadedAds.append(nativeAd)

            self.output?.nativeAdLoader(
                self,
                didLoad: nativeAd
            )
            self.onAdLoadedHandler?(nativeAd, index)

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

            let index = self.loadedAds.count
            self.incrementErrorCounter()

            self.output?.nativeAdLoader(
                self,
                didFailWith: error
            )
            self.onAdFailedHandler?(index, error)

            guard self.loadedAds.count < self.targetCount else {
                self.finish()
                return
            }

            self.loadNextIfPossible(sessionID: sessionID)
        }
    }
}

// MARK: - SwiftUI Inline Native Ad View

import SwiftUI

public struct InlineNativeAdView: UIViewRepresentable {
    public let nativeAd: NativeAd
    public let adView: NativeAdView

    public init(nativeAd: NativeAd, adView: NativeAdView) {
        self.nativeAd = nativeAd
        self.adView = adView
    }

    public func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.clipsToBounds = true
        renderNativeAd(in: containerView, adView: adView, nativeAd: nativeAd)
        return containerView
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        renderNativeAd(in: uiView, adView: adView, nativeAd: nativeAd)
    }

    private func renderNativeAd(in containerView: UIView, adView: NativeAdView, nativeAd: NativeAd) {
        containerView.subviews.forEach { $0.removeFromSuperview() }

        adView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(adView)

        NSLayoutConstraint.activate([
            adView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            adView.topAnchor.constraint(equalTo: containerView.topAnchor),
            adView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        adView.nativeAd = nativeAd
        adView.mediaView?.contentMode = .scaleAspectFill
        adView.mediaView?.clipsToBounds = true
        adView.mediaView?.mediaContent = nativeAd.mediaContent

        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        (adView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        (adView.priceView as? UILabel)?.text = nativeAd.price
        (adView.storeView as? UILabel)?.text = nativeAd.store
        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)

        if let starRating = nativeAd.starRating {
            (adView.starRatingView as? UIImageView)?.image = getStarRatingImage(for: starRating)
            adView.starRatingView?.isHidden = false
        } else {
            adView.starRatingView?.isHidden = true
        }

        adView.callToActionView?.isUserInteractionEnabled = false
    }
}

extension AdLoader: @unchecked Sendable {}
