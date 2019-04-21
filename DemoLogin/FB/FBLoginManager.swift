import UIKit

public enum ReadPermissions: String {
	case email = "email"
}

typealias LoginBlock = (Result<LoginResult, Error>) -> Void

class FBLoginManager {

	static let version = "5.0.0-rc.1"
	static let scheme = "fbauth2"
	var defaultAudience: Audience = .friends

	enum State {
		case idle
		case start
		case performingLogin
	}

	enum Audience: String {
		case onlyMe = "only_me"
		case friends = "friends"
		case everyone = "everyone"
	}

	private var state: State = .idle
	func login(permissions: Set<ReadPermissions>, sourceVC: UIViewController, completion: LoginBlock) {
		FBLoginManager.validateURLSchemes()

		var loginParams: [String: Any] = [
			"client_id": FBLoginManager.appID,
			"response_type": "token,signed_request",
			"redirect_uri": "fbconnect://success",
			"display": "touch",
			"sdk": "ios",
			"return_scopes": "true",
			"sdk_version": FBLoginManager.version,
			"fbapp_pres": Applications.isFacebookAppInstalled,
			"auth_type": "rerequest",
			"default_audience": self.defaultAudience,
			"scope": permissions.map({ $0.rawValue }).joined(separator: ",")
		]

		let challenge = self.stringForChallenge().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
		let state = [ "challenge": challenge ]
		loginParams["state"] = JSONSerialization.jsonEncodedString(with: state)

//		NSString *expectedChallenge = [FBSDKLoginManager stringForChallenge];
//		NSDictionary *state = @{@"challenge": [FBSDKUtility URLEncode:expectedChallenge]};
//		loginParams[@"state"] = [FBSDKInternalUtility JSONStringForObject:state error:NULL invalidObjectHandler:nil];
//
//		[self storeExpectedChallenge:expectedChallenge];
	}

	private func stringForChallenge() -> String {
		let challenge = String(UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(20))
		return challenge.replacingOccurrences(of: "+", with: "=")
	}

	class func validateURLSchemes() {
		self.validateAppID()
		let scheme = "fb\(self.appID)"
		assert(InfoHelpers.isRegisteredURLScheme(scheme), "You should register ")
	}

	private static var appID: String = {
		return UserDefaults.standard.string(forKey: "FacebookAppID") ?? ""
	}()
	class func set(appId: String) {
		self.appID = appId
	}
	class func validateAppID() {
		assert(!self.appID.isEmpty, "You should set app id")
	}

}

extension JSONSerialization {

	class func jsonEncodedString(with object: Any) -> String {
		guard let data = try? JSONSerialization.data(withJSONObject: object, options: []),
			let text = String(data: data, encoding: .utf8) else { return "" }
		return text
	}

}

struct LoginResult {
	let token: Token
	let isCancelled: Bool
	let grantedPermissions: Set<ReadPermissions>
	let declinedPermissions: Set<ReadPermissions>
}

struct Token {

}


//+ (void)validateURLSchemes
//	{
//		[self validateAppID];
//		NSString *defaultUrlScheme = [NSString stringWithFormat:@"fb%@%@", [FBSDKSettings appID], [FBSDKSettings appURLSchemeSuffix] ?: @""];
//		if (![self isRegisteredURLScheme:defaultUrlScheme]) {
//			NSString *reason = [NSString stringWithFormat:@"%@ is not registered as a URL scheme. Please add it in your Info.plist", defaultUrlScheme];
//			@throw [NSException exceptionWithName:@"InvalidOperationException" reason:reason userInfo:nil];
//		}
//}
