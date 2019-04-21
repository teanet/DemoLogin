import UIKit

class Applications {

	static var isFacebookAppInstalled: Bool {
		return canOpenScheme(FBLoginManager.scheme)

	}

	class func canOpenScheme(_ scheme: String) -> Bool {
		guard InfoHelpers.applicationQueriesSchemes.contains(scheme) else {
			print("\(scheme) is missing from your Info.plist under LSApplicationQueriesSchemes and is required for iOS 9.0")
			return false
		}

		var components = URLComponents()
		components.scheme = scheme
		components.path = "/"
		return UIApplication.shared.canOpenURL(components.url!)
	}

}
