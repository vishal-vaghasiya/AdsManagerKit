import SwiftUI
import AdsManagerKit
import GoogleMobileAds
import UIKit

struct InlineBannerContentView: View {
    
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
    
    var body: some View {
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
                            InlineBannerAdView(adIndex: index / adInterval)
                                .frame(height: 60)
                                .padding(.vertical, 12)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Inline Banner Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InlineBannerContentView()
    }
}
