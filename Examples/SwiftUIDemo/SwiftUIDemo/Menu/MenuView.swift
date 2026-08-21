import SwiftUI

struct MenuView: View {
    private let items: [MenuItem] = [
        .banner,
        .inlineBanner,
        .native,
        .inlineNative
    ]
    
    var body: some View {
        NavigationView {
            List(items) { item in
                NavigationLink(destination: item.contentView) {
                    Text(item.rawValue)
                }
            }
        }
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView()
    }
}
