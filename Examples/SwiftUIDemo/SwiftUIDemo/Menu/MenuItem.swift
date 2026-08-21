import Foundation
import AdsManagerKit
import SwiftUI

enum MenuItem: String, Identifiable {
    var id: Self { self }
    
    case banner = "Banner"
    case inlineBanner = "InlineBanner"
    case native = "Native"
    case inlineNative = "InlineNative"
    
    var contentView: some View {
        viewForType()
    }
}

extension MenuItem {
    @ViewBuilder
    private func viewForType() -> some View {
        switch self {
        case .banner:
            BannerContentView()
            
        case .inlineBanner:
            InlineBannerContentView()
            
        case .native:
            NativeContentView()
            
        case .inlineNative:
            InlineNativeContentView()
        }
    }
}

struct MenuItemButton: View {
    let item: MenuItem
    @Binding var selectedMenuItem: MenuItem?
    
    var body: some View {
        Button {
            AdsManager.shared.showInterstitialIfAvailable()
            selectedMenuItem = item
        } label: {
            Text(item.rawValue)
        }
    }
}
