import UIKit

public enum ReadPermissions: String {
	case email = "email"
}

typealias LoginBlock = (Result<LoginResult, Error>) -> Void

public protocol IOpenUrlHandler: AnyObject {
	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool
	func canOpenURL(_ url: URL, application: UIApplication, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool
}

final class FBLoginManager {

	@objc static var fbAppID = InfoHelpers.fbAppID

	static func validateFBAppID() {
		assert(!self.fbAppID.isEmpty, "You should set app id in your Info.plist using key: FacebookAppID")
	}

	static let version = "5.0.0-rc.1"
	var defaultAudience: Audience = .friends
	private var isUsedSFAuthSession = false
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
	var isPerformingLogin: Bool { return self.state == .performingLogin }
	private var useSafariViewController = false
	private lazy var bridgeAPI = BridgeAPI()
	private weak var fromViewController: UIViewController?
	private var requestedPermissions = Set<String>()
	private var completion: LoginBlock?
	private let tokenCache: AccessTokenCache
	private(set) var currentAccessToken: Token?

	init() {
		self.tokenCache = AccessTokenCache()
		self.currentAccessToken = self.tokenCache.fbAccessToken
	}

	func login(permissions: Set<ReadPermissions>, sourceVC: UIViewController, completion: @escaping LoginBlock) {
		FBLoginManager.validateURLSchemes()
		self.completion = completion
		self.isUsedSFAuthSession = false
		self.fromViewController = sourceVC
		var loginParams: [String: String] = [
			"client_id": InfoHelpers.fbAppID,
			"response_type": "token,signed_request",
			"redirect_uri": "fbconnect://success",
			"display": "touch",
			"sdk": "ios",
			"return_scopes": "true",
			"sdk_version": FBLoginManager.version,
			"fbapp_pres": Applications.isFacebookAppInstalled ? "1" : "0",
			"auth_type": "rerequest",
			"default_audience": self.defaultAudience.rawValue,
			"scope": permissions.map({ $0.rawValue }).joined(separator: ",")
		]

		let challenge = self.stringForChallenge().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
		self.challenge = challenge
		let state = [ "challenge": challenge ]
		loginParams["state"] = JSONSerialization.jsonEncodedString(with: state)
		self.performBrowserLogInWithParameters(loginParams) { [weak self] result in
			switch result {
				case .success(_):
					self?.state = .performingLogin
				case .failure(let error):
					if ErrorDomains.external.contains((error as NSError).domain) {
						self?.handleImplicitCancelOfLogIn()
					} else {
						self?.invokeHandler(result: .failure(error))
					}
			}
		}
	}

	private let FBSDKExpectedChallengeKey = "expected_login_challenge"
	private var challenge: String? {
		get {
			return KeychainStore.loginManager.string(for: FBSDKExpectedChallengeKey)
		}
		set {
			KeychainStore.loginManager.set(string: newValue, for: FBSDKExpectedChallengeKey, accessibility: .afterFirstUnlockThisDeviceOnly)
		}
	}

	private func performBrowserLogInWithParameters(_ params: [String: String], completion: @escaping BridgeAPI.SessionCompletionHandler) {
		var loginParams = params
		loginParams["redirect_uri"] = FBURL.redirectUri
		self.isUsedSFAuthSession = true
		let url = FBURL.facebookURL(with: "m.", path: FBURL.oAuthPath, query: loginParams)
		self.bridgeAPI.open(url: url, sender: self, fromVC: self.fromViewController, completion: completion)
	}

	private func invokeHandler(result: Result<LoginResult, Error>) {
		self.state = .idle
		if let handler = self.completion {
			handler(result)
			self.completion = nil
		}
	}

	private func stringForChallenge() -> String {
		let challenge = String(UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(20))
		return challenge.replacingOccurrences(of: "+", with: "=")
	}

	func handleImplicitCancelOfLogIn() {

	}

	class func validateURLSchemes() {
		self.validateFBAppID()
		assert(InfoHelpers.isRegisteredURLScheme(FBURL.myRedirectScheme), "You should register \(FBURL.myRedirectScheme) in your Info.plist")
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
	let token: Token?
	let isCancelled: Bool
	let grantedPermissions: Set<String>
	let declinedPermissions: Set<String>
}

struct Token: Codable {
	let tokenString: String
	let permissions: Set<String>
	let declinedPermissions: Set<String>
	let appID: String
	let userID: String
	let expirationDate: Date?
	let refreshDate: Date?
	let dataAccessExpirationDate: Date?
}

extension FBLoginManager: IOpenUrlHandler {

	func canOpenURL(_ url: URL, application: UIApplication, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
		return FBURL.canOpenUrl(url, sourceApplication: options[.sourceApplication] as? String)
	}

	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
		let isFacebookURL = self.canOpenURL(url, application: app, options: options)

		if !isFacebookURL && self.isPerformingLogin  {
			self.handleImplicitCancelOfLogIn()
		}

		if isFacebookURL {
			let completer = FBLoginCompletion(url: url)
			completer.complete(self) { [weak self] (result) in
				self?.completeAuthentication(result)
			}
		}
		return isFacebookURL
	}

	private func completeAuthentication(_ result: FBLoginCompletion.LoginCompletionResult) {

		guard case .success(let parameters) = result else {
			self.invokeHandler(result: .failure(result.error ?? FBSDKLoginError.unknown))
			return
		}

		let token = parameters.accessTokenString
		let cancelled = token.count == 0
		let challengeReceived = parameters.challenge
		let challengeExpected = self.challenge?.replacingOccurrences(of: "+", with: " ")
		let challengePassed = challengeExpected == challengeReceived
		self.challenge = nil

		if !cancelled && !challengePassed {
			self.invokeHandler(result: .failure(FBSDKLoginError.badChallenge))
			return
		}

		var result: LoginResult?
		if !cancelled {
			var recentlyGrantedPermissions = parameters.permissions
			let declinedPermissions = parameters.declinedPermissions
			let previouslyGrantedPermissions = self.currentAccessToken?.permissions ?? Set<String>()
			if !previouslyGrantedPermissions.isEmpty && !self.requestedPermissions.isEmpty {
				// If there were no requested permissions for this auth - treat all permissions as granted.
				// Otherwise this is a reauth, so recentlyGranted should be a subset of what was requested.
				recentlyGrantedPermissions.formIntersection(self.requestedPermissions)
			}

			let recentlyDeclinedPermissions = self.requestedPermissions.intersection(declinedPermissions)
			if !recentlyGrantedPermissions.isEmpty {
				let token = Token(
					tokenString: token,
					permissions: parameters.permissions,
					declinedPermissions: declinedPermissions,
					appID: parameters.appID,
					userID: parameters.userID,
					expirationDate: parameters.expirationDate,
					refreshDate: Date(),
					dataAccessExpirationDate: parameters.dataAccessExpirationDate
				)
				result = LoginResult(
					token: token,
					isCancelled: false,
					grantedPermissions: recentlyGrantedPermissions,
					declinedPermissions: recentlyDeclinedPermissions
				)
				/// TODO: Если у нас есть токен, то попробуем обновить его время жизни, пока ничего не делаем
				//	if ([FBSDKAccessToken currentAccessToken]) {
				//		[self validateReauthentication:[FBSDKAccessToken currentAccessToken] withResult:result];
				//		// in a reauth, short circuit and let the login handler be called when the validation finishes.
				//		return;
				//	}
			}

			if cancelled || recentlyGrantedPermissions.isEmpty {
				var declinedPermissions = Set<String>()
				if self.currentAccessToken != nil {
					// Always include the list of declined permissions from this login request
					// if an access token is already cached by the SDK
					declinedPermissions = recentlyDeclinedPermissions
				}
				result = LoginResult(
					token: nil,
					isCancelled: cancelled,
					grantedPermissions: [],
					declinedPermissions: declinedPermissions
				)
			}
		}

		if let token = result?.token {
			self.currentAccessToken = token
			self.tokenCache.fbAccessToken = token
		}

		if let result = result {
			self.invokeHandler(result: .success(result))
		} else {
			self.invokeHandler(result: .failure(FBSDKLoginError.unknown))
		}
	}

}
