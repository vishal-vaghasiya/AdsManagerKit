import UIKit
import JGProgressHUD

@MainActor
public final class AppProgressHUD {

    private static var hud = JGProgressHUD()

    // MARK: - Helpers
    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    // MARK: - Loading
    public static func show() {
        resetHUD()
        hud.square = true
        showHUD()
    }

    public static func show(status: String) {
        resetHUD()
        hud.textLabel.text = status
        hud.square = false
        showHUD()
    }

    public static func show(progress: CGFloat, status: String, on view: UIView) {
        resetHUD()
        hud.indicatorView = JGProgressHUDRingIndicatorView()
        hud.progress = Float(progress)
        hud.textLabel.text = status
        hud.detailTextLabel.text = "\(Int(progress * 100))% Complete"
        hud.show(in: view)
    }

    // MARK: - Success / Error
    public static func showSuccess(
        status: String = "Success",
        completion: (() -> Void)? = nil
    ) {
        resetHUD()
        hud.textLabel.text = status
        hud.indicatorView = JGProgressHUDSuccessIndicatorView()
        showHUD()
        dismiss(after: 2, completion: completion)
    }

    public static func showError(
        status: String,
        completion: (() -> Void)? = nil
    ) {
        resetHUD()
        hud.textLabel.text = status
        hud.indicatorView = JGProgressHUDErrorIndicatorView()
        showHUD()
        dismiss(after: 2, completion: completion)
    }

    // MARK: - Dismiss
    public static func dismiss(
        after delay: TimeInterval = 0,
        completion: (() -> Void)? = nil
    ) {
        hud.dismiss(afterDelay: delay, animated: true) {
            resetHUD()
            completion?()
        }
    }

    // MARK: - Private
    private static func showHUD() {
        guard let window = keyWindow else { return }
        hud.show(in: window)
    }

    private static func resetHUD() {
        hud = JGProgressHUD(style: .dark)
    }
}
