import GoogleMobileAds
import Foundation
import UIKit

public protocol NativeAdLoaderOutput: AnyObject {
    func nativeAdLoader(_ loader: NativeAdLoader, didLoad ad: NativeAd)
    func nativeAdLoader(_ loader: NativeAdLoader, didFailWith error: Error)
}

@MainActor
public final class NativeAdLoader: NSObject {
    
    public static let shared = NativeAdLoader()
    
    // MARK: - State
    private var targetCount: Int = 0
    private var loadedAds: [NativeAd] = []
    private var activeLoaders: Set<AdLoader> = []
    
    private var completion: (([NativeAd]) -> Void)?
    private weak var rootViewController: UIViewController?
    
    private var currentNativeAdErrorCount: Int = 0
    private var lastNativeAdErrorTime: Date?
    private let nativeAdRetryCooldown: TimeInterval = 90 // seconds (optimized for native ads stability & eCPM)
    
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
        
        self.targetCount = count
        self.loadedAds = []
        self.activeLoaders.removeAll()
        self.completion = completion
        self.rootViewController = rootViewController
        if let output = rootViewController as? NativeAdLoaderOutput {
            self.output = output
        }
        
        loadNextIfPossible()
    }
    
    // MARK: - Loading Logic
    private func loadNextIfPossible() {
        // Stop conditions
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
        activeLoaders.insert(loader)
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
        completion?(loadedAds)
        completion = nil
        rootViewController = nil
        activeLoaders.removeAll()
    }
}

// MARK: - NativeAdLoaderDelegate
extension NativeAdLoader: NativeAdLoaderDelegate {
    
    nonisolated public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        Task { @MainActor in
            self.activeLoaders.remove(adLoader)
            self.resetErrorCounter()
            self.loadedAds.append(nativeAd)
            self.output?.nativeAdLoader(self, didLoad: nativeAd)
            guard self.loadedAds.count < self.targetCount else {
                self.finish()
                return
            }
            self.loadNextIfPossible()
        }
    }
    
    @objc nonisolated public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            self.activeLoaders.remove(adLoader)
            self.incrementErrorCounter()
            self.output?.nativeAdLoader(self, didFailWith: error)
            guard self.loadedAds.count < self.targetCount else {
                self.finish()
                return
            }
            self.loadNextIfPossible()
        }
    }
}

extension AdLoader: @unchecked Sendable {}
