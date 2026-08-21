import UIKit
import GoogleMobileAds

// MARK: - Inline Banner Container
public final class InlineBannerContainerView: UIView {

    var adIndex: Int = 0

    private var didStartLoading = false
    private var bannerView: BannerView?

    public override func layoutSubviews() {
        super.layoutSubviews()

        loadAdIfNeeded()
    }

    func loadAdIfNeeded() {

        guard !didStartLoading else {
            return
        }

        guard bounds.width > 0 else {
            return
        }

        guard let viewController =
                findViewController() else {
            return
        }

        didStartLoading = true

        InlineBannerAdManager.shared.loadBannerAds(
            count: 1,
            rootViewController: viewController,
            width: bounds.width
        ) { [weak self] banners in

            guard let self else {
                return
            }

            guard let banner = banners.first else {
                return
            }

            DispatchQueue.main.async {

                self.bannerView?.removeFromSuperview()

                self.bannerView = banner

                banner.translatesAutoresizingMaskIntoConstraints = false

                self.addSubview(banner)

                NSLayoutConstraint.activate([
                    banner.topAnchor.constraint(
                        equalTo: self.topAnchor
                    ),

                    banner.leadingAnchor.constraint(
                        equalTo: self.leadingAnchor
                    ),

                    banner.trailingAnchor.constraint(
                        equalTo: self.trailingAnchor
                    ),

                    banner.heightAnchor.constraint(
                        equalToConstant: banner.adSize.size.height
                    )
                ])
            }
        }
    }

    // MARK: - Find View Controller

    private func findViewController() -> UIViewController? {

        var responder: UIResponder? = self

        while let current = responder {

            if let viewController =
                current as? UIViewController {

                return viewController
            }

            responder = current.next
        }

        return nil
    }

    // MARK: - Cleanup

    deinit {
        bannerView?.removeFromSuperview()
        bannerView = nil
    }
}
