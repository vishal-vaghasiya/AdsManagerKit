import UIKit
import GoogleMobileAds

final class InlineBannerTableViewCell: UITableViewCell {

    // MARK: - Properties

    private let containerView = UIView()

    private var bannerView: BannerView?

    // MARK: - Initialization

    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(
            style: style,
            reuseIdentifier: reuseIdentifier
        )

        setupUI()
    }

    required init?(
        coder: NSCoder
    ) {
        super.init(coder: coder)

        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {

        selectionStyle = .none

        contentView.addSubview(containerView)

        containerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(
                equalTo: contentView.topAnchor
            ),

            containerView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),

            containerView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),

            containerView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor
            )
        ])
    }

    // MARK: - Configure

    func configure(
        with bannerView: BannerView
    ) {

        clearBanner()

        self.bannerView = bannerView

        containerView.addSubview(bannerView)

        bannerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(
                equalTo: containerView.topAnchor
            ),

            bannerView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor
            ),

            bannerView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor
            ),

            bannerView.heightAnchor.constraint(
                equalToConstant: bannerView.adSize.size.height
            ),

            bannerView.bottomAnchor.constraint(
                equalTo: containerView.bottomAnchor
            )
        ])
    }

    // MARK: - Clear

    func clearBanner() {

        bannerView?.removeFromSuperview()
        bannerView = nil

        containerView.subviews.forEach {
            $0.removeFromSuperview()
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()

        clearBanner()
    }
}
