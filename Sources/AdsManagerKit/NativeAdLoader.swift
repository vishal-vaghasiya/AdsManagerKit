import GoogleMobileAds
import Foundation
@MainActor
public final class NativeAdLoader: NSObject {
    
    public static let shared = NativeAdLoader()
    
    private var targetCount = 0
    private var loadedAds: [NativeAd] = []
    private var errorCount = 0
    private let maxErrorLimit = 3
    private var completion: (([NativeAd]) -> Void)?
    private var loaders: [AdLoader] = []
    
    public override init() {
        super.init()
    }
    
    public func loadNativeAds(
        count: Int,
        completion: @escaping ([NativeAd]) -> Void
    ) {
        guard AdsConfig.nativeAdEnabled else {
            completion([])
            return
        }
        
        // Reset each fresh call
        self.targetCount = count
        self.loadedAds = []
        self.errorCount = 0
        self.loaders.removeAll()
        self.completion = completion
        
        loadNext()
    }
    
    private func loadNext() {
        // Stop conditions
        if loadedAds.count >= targetCount {
            completion?(loadedAds)
            return
        }
        if errorCount >= maxErrorLimit {
            completion?(loadedAds)
            return
        }
        
        let loader = AdLoader(
            adUnitID: AdsConfig.nativeAdUnitId,
            rootViewController: nil,
            adTypes: [.native],
            options: nil
        )
        
        loader.delegate = self
        loaders.append(loader)
        loader.load(Request())
    }
}

// MARK: - NativeAdLoaderDelegate
extension NativeAdLoader: NativeAdLoaderDelegate {
    nonisolated public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        
        let loaderID = ObjectIdentifier(adLoader)
        Task { @MainActor in
            loadedAds.append(nativeAd)
            loadNext()
        }
    }
    
    nonisolated public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        let loaderID = ObjectIdentifier(adLoader)
        Task { @MainActor in
            errorCount += 1
            loadNext()
        }
    }
}
