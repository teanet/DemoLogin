import UIKit
extension UIApplication {

	static func findWindow() -> UIWindow? {
		var keyWindow = self.shared.keyWindow
		if keyWindow == nil || keyWindow?.windowLevel != .normal {
			for window in self.shared.windows {
				if window.windowLevel == .normal {
					keyWindow = window
					break
				}
			}
		}
		return keyWindow
	}

	static func topMostViewController() -> UIViewController? {
		guard let keyWindow = self.findWindow() else { return nil }
		if !keyWindow.isKeyWindow {
			keyWindow.makeKey()
		}
		guard var topVC = keyWindow.rootViewController else { return nil }

		while let presentedViewController = topVC.presentedViewController {
			topVC = presentedViewController
		}
		return topVC
	}

}
