import UIKit
import GoogleMobileAds

// MARK: - Inline Banner Container
public final class InlineBannerContainerView: UIView {

    var adIndex: Int = 0
    var onAdLoaded: ((CGFloat) -> Void)?
    var onAdFailed: ((Error) -> Void)?

    private var didStartLoading = false
    private(set) var bannerView: BannerView?
    private var shimmerView: AdShimmerView?

    public override var intrinsicContentSize: CGSize {
        if let bannerView = bannerView {
            return CGSize(width: UIView.noIntrinsicMetric, height: bannerView.adSize.size.height)
        }
        if didStartLoading && bannerView == nil {
            return CGSize(width: UIView.noIntrinsicMetric, height: 60)
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: 0)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        if bannerView == nil {
            loadAdIfNeeded()
        }
    }

    public func setBannerView(_ banner: BannerView) {
        hideShimmer()

        if self.bannerView == banner && banner.superview == self {
            return
        }

        // If the banner belonged to another container previously, unbind it from that container
        if let previousContainer = banner.superview as? InlineBannerContainerView, previousContainer != self {
            previousContainer.bannerView = nil
        }

        if self.bannerView != banner {
            if self.bannerView?.superview == self {
                self.bannerView?.removeFromSuperview()
            }
        }
        self.bannerView = banner

        if banner.superview != self {
            banner.removeFromSuperview()
            banner.translatesAutoresizingMaskIntoConstraints = false
            addSubview(banner)

            NSLayoutConstraint.activate([
                banner.topAnchor.constraint(equalTo: topAnchor),
                banner.leadingAnchor.constraint(equalTo: leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: trailingAnchor),
                banner.bottomAnchor.constraint(equalTo: bottomAnchor),
                banner.heightAnchor.constraint(equalToConstant: banner.adSize.size.height)
            ])
        }

        invalidateIntrinsicContentSize()
        setNeedsLayout()

        onAdLoaded?(banner.adSize.size.height)
    }

    public func clearBanner() {
        hideShimmer()
        if bannerView?.superview == self {
            bannerView?.removeFromSuperview()
        }
        bannerView = nil
        invalidateIntrinsicContentSize()
    }

    private func showShimmer() {
        hideShimmer()
        let shimmer = AdShimmerView()
        self.shimmerView = shimmer
        shimmer.show(in: self, height: 60)
        invalidateIntrinsicContentSize()
    }

    private func hideShimmer() {
        shimmerView?.remove()
        shimmerView = nil
        invalidateIntrinsicContentSize()
    }

    func loadAdIfNeeded() {
        guard bannerView == nil, !didStartLoading else {
            return
        }

        guard bounds.width > 0 else {
            return
        }

        guard let viewController = findViewController() else {
            return
        }

        didStartLoading = true
        showShimmer()

        InlineBannerAdManager.shared.loadBannerAds(
            count: 1,
            rootViewController: viewController,
            width: bounds.width
        ) { [weak self] banners in

            guard let self else {
                return
            }

            DispatchQueue.main.async {
                self.hideShimmer()
                if let banner = banners.first {
                    self.setBannerView(banner)
                } else {
                    self.clearBanner()
                    let error = NSError(
                        domain: "InlineBannerContainerView",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to load inline banner ad"]
                    )
                    self.onAdFailed?(error)
                }
            }
        }
    }

    // MARK: - Find View Controller

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self

        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }
            responder = current.next
        }

        return nil
    }

    // MARK: - Cleanup

    deinit {
        let banner = bannerView
        let shimmer = shimmerView
        if banner != nil || shimmer != nil {
            Task { @MainActor in
                shimmer?.remove()
                if banner?.superview != nil {
                    banner?.removeFromSuperview()
                }
            }
        }
    }
}
