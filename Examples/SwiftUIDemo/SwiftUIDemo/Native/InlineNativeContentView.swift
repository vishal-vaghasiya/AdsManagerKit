
import AdsManagerKit
import GoogleMobileAds
import SwiftUI

struct InlineNativeContentView: View {

    @State private var loadedNativeAds: [Int: NativeAd] = [:]
    @State private var failedAdIndexes: Set<Int> = []
    @State private var isLoadingStarted = false

    private let items = (1...25).map { "Feed Item \($0)" }
    private let adInterval = 5
    private var adCount: Int { items.count / adInterval }

    var body: some View {
        List {
            Section("Inline Native Ads") {
                ForEach(0..<items.count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(items[index])
                            .font(.headline)
                        Text("This is item description number \(index + 1) in the scrollable list.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if (index + 1) % adInterval == 0 {
                            let adIndex = (index + 1) / adInterval - 1
                            Group {
                                if let nativeAd = loadedNativeAds[adIndex] {
                                    InlineNativeAdView(nativeAd: nativeAd, adView: loadNibAdView())
                                        .frame(height: 250)
                                        .padding(.vertical, 8)
                                } else if failedAdIndexes.contains(adIndex) {
                                    EmptyView()
                                } else {
                                    AdShimmerViewRepresentable(height: 250)
                                        .frame(height: 250)
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Inline Native")
        .onAppear {
            loadInlineNativeAds()
        }
    }

    private func loadInlineNativeAds() {
        guard !isLoadingStarted else { return }
        isLoadingStarted = true

        guard let rootVC = UIApplication.shared.adsManagerRootViewController else {
            return
        }

        InlineNativeAdManager.shared.loadNativeAds(
            count: adCount,
            rootViewController: rootVC,
            onAdLoaded: { ad, index in
                loadedNativeAds[index] = ad
            },
            onAdFailed: { index, _ in
                failedAdIndexes.insert(index)
            },
            completion: { ads in
                print("Completed loading \(ads.count) inline native ads")
            }
        )
    }

    private func loadNibAdView() -> NativeAdView {
        let bundle = Bundle(for: NativeAdView.self)
        guard let adView = bundle.loadNibNamed("NativeAdView", owner: nil, options: nil)?.first as? NativeAdView else {
            fatalError("Could not load NativeAdView.xib")
        }
        return adView
    }
}

private extension UIApplication {
    var adsManagerRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }
}

#Preview {
    InlineNativeContentView()
}

