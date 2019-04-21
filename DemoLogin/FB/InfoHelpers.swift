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
