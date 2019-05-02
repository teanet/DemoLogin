import UIKit

public enum ReadPermissions: String {
	case email = "email"
}

typealias LoginBlock = (Result<LoginResult, Error>) -> Void

public protocol IOpenUrlHandler {
	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool
}

struct ErrorDomains {
	static let SFVCCanceledLogin = "com.apple.SafariServices.Authentication"
	static let ASCanceledLogin = "com.apple.AuthenticationServices.WebAuthenticationSession"

	static let FBSDKLoginErrorDomain = "com.facebook.sdk.login"

	static var external = [ SFVCCanceledLogin, ASCanceledLogin ]
}

enum FBSDKLoginError: Int, Error {
	case reserved = 300
	/// The error code for unknown errors.
	case unknown

	var domain: String {
		return ErrorDomains.FBSDKLoginErrorDomain
	}

}

class FBLoginManager {

	static let version = "5.0.0-rc.1"
	static let fbApplicationScheme = "fbauth2"
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

	func login(permissions: Set<ReadPermissions>, sourceVC: UIViewController, completion: LoginBlock) {
		FBLoginManager.validateURLSchemes()
		self.isUsedSFAuthSession = false
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


//		void(^completion)(BOOL, NSString *, NSError *) = ^void(BOOL didPerformLogIn, NSString *authMethod, NSError *error) {
//			if (didPerformLogIn) {
//				[self->_logger startAuthMethod:authMethod];
//				self->_state = FBSDKLoginManagerStatePerformingLogin;
//			} else if ([error.domain isEqualToString:SFVCCanceledLogin] ||
//				[error.domain isEqualToString:ASCanceledLogin]) {
//				[self handleImplicitCancelOfLogIn];
//			} else {
//				if (!error) {
//					error = [NSError errorWithDomain:FBSDKLoginErrorDomain code:FBSDKLoginErrorUnknown userInfo:nil];
//				}
//				[self invokeHandler:nil error:error];
//			}
//		};
//
//		[self performBrowserLogInWithParameters:loginParams handler:^(BOOL openedURL,
//			NSString *authMethod,
//			NSError *openedURLError) {
//			completion(openedURL, authMethod, openedURLError);
//			}];

		self.performBrowserLogInWithParameters(loginParams) { [weak self] (didPerformLogIn, authMethod, error) in
			if didPerformLogIn {
				self?.state = .performingLogin
			} else if let error = error, ErrorDomains.external.contains((error as NSError).domain) {
				self?.handleImplicitCancelOfLogIn()
			} else {
				let error = error ?? FBSDKLoginError.unknown
				self?.invokeHandler(result: .failure(error))
			}
		}


//		NSString *expectedChallenge = [FBSDKLoginManager stringForChallenge];
//		NSDictionary *state = @{@"challenge": [FBSDKUtility URLEncode:expectedChallenge]};
//		loginParams[@"state"] = [FBSDKInternalUtility JSONStringForObject:state error:NULL invalidObjectHandler:nil];
//
//		[self storeExpectedChallenge:expectedChallenge];
	}

	private func performBrowserLogInWithParameters(_ params: [String: Any], completion: @escaping (Bool, String, Error?) -> Void) {

	}

	func invokeHandler(result: Result<LoginResult, Error>) {

	}
//	- (void)invokeHandler:(FBSDKLoginManagerLoginResult *)result error:(NSError *)error
//	{
//	[_logger endLoginWithResult:result error:error];
//	[_logger endSession];
//	_logger = nil;
//	_state = FBSDKLoginManagerStateIdle;
//
//	if (_handler) {
//	FBSDKLoginManagerLoginResultBlock handler = _handler;
//	_handler(result, error);
//	if (handler == _handler) {
//	_handler = nil;
//	} else {
//	[FBSDKLogger singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors
//	formatString:@"** WARNING: You are requesting permissions inside the completion block of an existing login."
//	"This is unsupported behavior. You should request additional permissions only when they are needed, such as requesting for publish_actions"
//	"when the user performs a sharing action."];
//	}
//	}
//	}

	private func stringForChallenge() -> String {
		let challenge = String(UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(20))
		return challenge.replacingOccurrences(of: "+", with: "=")
	}

	func handleImplicitCancelOfLogIn() {

	}

	class func validateURLSchemes() {
		self.validateAppID()
		assert(InfoHelpers.isRegisteredURLScheme(self.myRedirectScheme), "You should register \(self.myRedirectScheme) in your Info.plist")
	}

	private static var myRedirectScheme: String {
		return "fb\(self.appID)"
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

extension FBLoginManager: IOpenUrlHandler {

	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
		let isFacebookURL = self.canOpenUrl(url, sourceApplication: options[.sourceApplication] as? String)

		if !isFacebookURL && self.isPerformingLogin  {
			self.handleImplicitCancelOfLogIn()
		}

		if isFacebookURL {
//			if (isFacebookURL) {
//				NSDictionary *urlParameters = [FBSDKLoginUtility queryParamsFromLoginURL:url];
//				id<FBSDKLoginCompleting> completer = [[FBSDKLoginURLCompleter alloc] initWithURLParameters:urlParameters appID:[FBSDKSettings appID]];
//
//				if (_logger == nil) {
//					_logger = [FBSDKLoginManagerLogger loggerFromParameters:urlParameters];
//				}
//
//				// any necessary strong reference is maintained by the FBSDKLoginURLCompleter handler
//				[completer completeLogIn:self withHandler:^(FBSDKLoginCompletionParameters *parameters) {
//					[self completeAuthentication:parameters expectChallenge:YES];
//					}];
//			}
		}
		return isFacebookURL
	}

	func canOpenUrl(_ url: URL, sourceApplication: String?) -> Bool {
		// verify the URL is intended as a callback for the SDK's log in
		let isFacebookURL = url.scheme?.hasPrefix(FBLoginManager.myRedirectScheme) == true &&
			url.host == "authorize"

		let isExpectedSourceApplication =
			sourceApplication?.hasPrefix("com.facebook") == true  ||
			sourceApplication?.hasPrefix("com.apple") == true ||
			sourceApplication?.hasPrefix("com.burbn") == true
		return isFacebookURL && isExpectedSourceApplication;
	}



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
