import AdsManagerKit
import SwiftUI
import GoogleMobileAds

struct BannerContentView: View {
    @State private var bannerIsLoaded = false
    @State private var bannerHeight: CGFloat = 50

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "rectangle.bottomthird.inset.filled")
                .font(.system(size: 56))

            Text("Welcome to Banner Ads")
                .font(.title)
                .fontWeight(.bold)

            Text("This demo shows how AdsManagerKit displays a standard banner ad in a SwiftUI application.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Text("Banner Ad Demo")
                    .font(.headline)

                Text("Ad Type: Regular Banner")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(
                    bannerIsLoaded
                    ? "Status: Loaded"
                    : "Status: Loading..."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BannerAdView(
                adType: .largeAdaptive,
                isLoaded: $bannerIsLoaded,
                height: $bannerHeight
            )
            .frame(height: bannerIsLoaded ? bannerHeight : 50)
        }
        .navigationTitle("Banner Ad Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BannerContentView()
    }
}
