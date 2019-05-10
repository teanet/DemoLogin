import Foundation
class InfoHelpers {

	static let infoPlist = Bundle.main.infoDictionary!
	static let bundleURLTypes = infoPlist["CFBundleURLTypes"] as? [[String: Any]] ?? []
	static let bundleURLSchemes: [String] = bundleURLTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
	static let applicationQueriesSchemes: [String] = infoPlist["LSApplicationQueriesSchemes"] as? [String] ?? []

	class func isRegisteredURLScheme(_ scheme: String) -> Bool {
		return self.bundleURLSchemes.contains(scheme)
	}

}

extension InfoHelpers {

	static var fbAppID: String = {
		return InfoHelpers.infoPlist["FacebookAppID"] as? String ?? ""
	}()

	static func validateFBAppID() {
		assert(!self.fbAppID.isEmpty, "You should set app id in your Info.plist using key: FacebookAppID")
	}

}
