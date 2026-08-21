import UIKit

final class AdShimmerView: UIView {
    
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .systemGray6
        clipsToBounds = true
        isUserInteractionEnabled = false
        
        gradientLayer.colors = [
            UIColor.systemGray6.cgColor,
            UIColor.systemGray4.cgColor,
            UIColor.systemGray6.cgColor
        ]
        
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        
        layer.addSublayer(gradientLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    func show(
        in containerView: UIView,
        height: CGFloat
    ) {
        containerView.subviews.forEach {
            $0.removeFromSuperview()
        }
        
        translatesAutoresizingMaskIntoConstraints = false
        
        containerView.clipsToBounds = true
        containerView.addSubview(self)
        
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor
            ),
            trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor
            ),
            topAnchor.constraint(
                equalTo: containerView.topAnchor
            ),
            heightAnchor.constraint(
                equalToConstant: height
            )
        ])
        
        startAnimating()
    }
    
    func remove() {
        stopAnimating()
        removeFromSuperview()
    }
    
    private func startAnimating() {
        gradientLayer.removeAnimation(
            forKey: "adShimmer"
        )
        
        let animation = CABasicAnimation(
            keyPath: "locations"
        )
        
        animation.fromValue = [-1, -0.5, 0]
        animation.toValue = [1, 1.5, 2]
        animation.duration = 1.2
        animation.repeatCount = .infinity
        animation.timingFunction =
            CAMediaTimingFunction(
                name: .easeInEaseOut
            )
        
        gradientLayer.add(
            animation,
            forKey: "adShimmer"
        )
    }
    
    private func stopAnimating() {
        gradientLayer.removeAnimation(
            forKey: "adShimmer"
        )
    }
}

// MARK: - SwiftUI Representable
import SwiftUI

public struct AdShimmerViewRepresentable: UIViewRepresentable {
    public let height: CGFloat

    public init(height: CGFloat = 60) {
        self.height = height
    }

    public func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        let shimmer = AdShimmerView()
        shimmer.show(in: container, height: height)
        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}
}
