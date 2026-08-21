import SwiftUI

public struct InlineBannerAdView: UIViewRepresentable {

    public let adIndex: Int

    public init(adIndex: Int) {
        self.adIndex = adIndex
    }

    public func makeUIView(context: Context) -> UIView {
        let containerView = InlineBannerContainerView()

        containerView.backgroundColor = .clear
        containerView.adIndex = adIndex

        return containerView
    }

    public func updateUIView(
        _ uiView: UIView,
        context: Context
    ) {
        guard let containerView =
                uiView as? InlineBannerContainerView else {
            return
        }

        containerView.adIndex = adIndex
        containerView.loadAdIfNeeded()
    }
}
