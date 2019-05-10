import UIKit

public enum ReadPermissions: String {
	case email = "email"
}

typealias LoginBlock = (Result<LoginResult, Error>) -> Void

public protocol IOpenUrlHandler: AnyObject {
	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool
	func canOpenURL(_ url: URL, application: UIApplication, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool
}

class FBLoginManager {

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

	func login(permissions: Set<ReadPermissions>, sourceVC: UIViewController, completion: LoginBlock) {
		FBLoginManager.validateURLSchemes()
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

	private func performBrowserLogInWithParameters(_ params: [String: String], completion: @escaping (Bool, String, Error?) -> Void) {
		var loginParams = params
		if let redirectURL = FBURL.redirectUri {
			loginParams["redirect_uri"] = redirectURL
		}

		self.isUsedSFAuthSession = true
		let url = FBURL.facebookURL(with: "m.", path: FBURL.oAuthPath, query: loginParams)
		self.bridgeAPI.open(url: url, sender: self, fromVC: self.fromViewController) { (result) in
			
		}


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
		InfoHelpers.validateFBAppID()
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
	let token: Token
	let isCancelled: Bool
	let grantedPermissions: Set<ReadPermissions>
	let declinedPermissions: Set<ReadPermissions>
}

struct Token {

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
