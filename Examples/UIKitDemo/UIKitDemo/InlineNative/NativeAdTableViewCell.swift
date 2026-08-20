import GoogleMobileAds
import UIKit

final class NativeAdTableViewCell: UITableViewCell {

    static let reuseIdentifier = "NativeAdTableViewCell"

    private let adView = NativeAdView()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(
            ofSize: 16,
            weight: .semibold
        )
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14)
        return label
    }()

    private let advertiserLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()

    private let callToActionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 8
        return button
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        return imageView
    }()

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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {

        selectionStyle = .none

        adView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(adView)

        adView.addSubview(stackView)

        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(headlineLabel)
        stackView.addArrangedSubview(bodyLabel)
        stackView.addArrangedSubview(advertiserLabel)
        stackView.addArrangedSubview(callToActionButton)

        NSLayoutConstraint.activate([

            // NativeAdView → Cell
            adView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 8
            ),

            adView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 16
            ),

            adView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -16
            ),

            adView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -8
            ),

            // Stack → NativeAdView
            stackView.topAnchor.constraint(
                equalTo: adView.topAnchor,
                constant: 12
            ),

            stackView.leadingAnchor.constraint(
                equalTo: adView.leadingAnchor,
                constant: 12
            ),

            stackView.trailingAnchor.constraint(
                equalTo: adView.trailingAnchor,
                constant: -12
            ),

            stackView.bottomAnchor.constraint(
                equalTo: adView.bottomAnchor,
                constant: -12
            ),

            // Give the icon a predictable aspect ratio.
            iconImageView.heightAnchor.constraint(
                equalTo: iconImageView.widthAnchor,
                multiplier: 0.56
            ),

            // CTA has a minimum tappable height.
            callToActionButton.heightAnchor.constraint(
                greaterThanOrEqualToConstant: 44
            )
        ])
    }

    func configure(with ad: NativeAd) {

        headlineLabel.text = ad.headline
        bodyLabel.text = ad.body
        advertiserLabel.text = ad.advertiser

        if let image = ad.images?.first {
            iconImageView.image = image.image
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = true
        }

        callToActionButton.setTitle(
            ad.callToAction,
            for: .normal
        )

        adView.nativeAd = ad
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        adView.nativeAd = nil

        headlineLabel.text = nil
        bodyLabel.text = nil
        advertiserLabel.text = nil
        iconImageView.image = nil
        callToActionButton.setTitle(nil, for: .normal)
    }
}
