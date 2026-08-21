import SwiftUI
import AdsManagerKit
import GoogleMobileAds
import UIKit

struct InlineBannerContentView: View {

    @State private var loadedBanners: [Int: BannerView] = [:]
    @State private var bannerHeights: [Int: CGFloat] = [:]
    @State private var failedAdIndexes: Set<Int> = []
    @State private var isAdLoadingStarted = false

    private let items = [
        "Item 1",
        "Item 2",
        "Item 3",
        "Item 4",
        "Item 5",
        "Item 6",
        "Item 7",
        "Item 8",
        "Item 9",
        "Item 10",
        "Item 11",
        "Item 12",
        "Item 13",
        "Item 14",
        "Item 15",
        "Item 16",
        "Item 17",
        "Item 18",
        "Item 19",
        "Item 20"
    ]

    private let adInterval = 4

    private var adCount: Int {
        items.count / adInterval
    }

    var body: some View {
        GeometryReader { geometry in
            List {
                // MARK: - Header
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 46))

                        Text("Welcome to Inline Banner Ads")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(
                            "This demo shows how AdsManagerKit displays banner ads between regular content items."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }

                // MARK: - Content
                Section("Demo Content") {
                    ForEach(0..<items.count, id: \.self) { index in
                        VStack(spacing: 0) {
                            // MARK: Normal Item
                            HStack(spacing: 14) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 8))

                                Text(items[index])
                                    .font(.body)

                                Spacer()
                            }
                            .padding(.vertical, 8)

                            // MARK: Inline Banner
                            if (index + 1) % adInterval == 0 {
                                let adIndex = index / adInterval
                                if let bannerView = loadedBanners[adIndex],
                                   let height = bannerHeights[adIndex], height > 0 {
                                    // Ad Loaded State
                                    InlineBannerAdView(bannerView: bannerView)
                                        .frame(height: height)
                                        .padding(.vertical, 12)
                                } else if failedAdIndexes.contains(adIndex) {
                                    // Ad Failed State: Height automatically set to 0
                                    EmptyView()
                                        .frame(height: 0)
                                } else {
                                    // Loading State: Show Shimmerview till InlineBanner loads
                                    AdShimmerViewRepresentable(height: 60)
                                        .frame(height: 60)
                                        .padding(.vertical, 12)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onAppear {
                loadAdsIfNeeded(width: geometry.size.width)
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                if newWidth > 0 {
                    InlineBannerAdManager.shared.updateWidth(newWidth)
                }
            }
            .onDisappear {
                InlineBannerAdManager.shared.reset()
                loadedBanners.removeAll()
                bannerHeights.removeAll()
                failedAdIndexes.removeAll()
                isAdLoadingStarted = false
            }
        }
        .navigationTitle("Inline Banner Demo")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadAdsIfNeeded(width: CGFloat) {
        guard !isAdLoadingStarted, width > 0 else {
            return
        }
        isAdLoadingStarted = true

        guard let rootVC = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            return
        }

        InlineBannerAdManager.shared.loadBannerAds(
            count: adCount,
            rootViewController: rootVC,
            width: width,
            onAdLoaded: { bannerView, index, height in
                DispatchQueue.main.async {
                    self.failedAdIndexes.remove(index)
                    self.loadedBanners[index] = bannerView
                    self.bannerHeights[index] = height
                }
            },
            onAdFailed: { index, error in
                DispatchQueue.main.async {
                    self.loadedBanners.removeValue(forKey: index)
                    self.bannerHeights.removeValue(forKey: index)
                    self.failedAdIndexes.insert(index)
                }
            },
            completion: { banners in
                #if DEBUG
                print("[InlineBannerContentView] Banners loading completed. Loaded: \(banners.count)/\(adCount)")
                #endif
            }
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InlineBannerContentView()
    }
}
