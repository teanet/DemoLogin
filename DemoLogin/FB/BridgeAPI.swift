import UIKit

protocol AuthenticationSession: AnyObject {
//		- (instancetype)initWithURL:(NSURL *)URL callbackURLScheme:(nullable NSString *)callbackURLScheme completionHandler:(FBSDKAuthenticationCompletionHandler)completionHandler;
	func start() -> Bool
	func cancel()
}

class BridgeAPI {

	typealias SessionCompletionHandler = (Result<Bool, Error>) -> Void
	typealias AuthenticationCompletionHandler = (Result<URL, Error>) -> Void

	private var expectingBackground = false
	private var isRequestingSFAuthenticationSession = false
	private weak var pendingURLOpen: IOpenUrlHandler?
	private var authenticationSessionCompletionHandler: AuthenticationCompletionHandler?
	private var authenticationSession: AuthenticationSession?

	private var sessionCompletionHandler: SessionCompletionHandler? {
		didSet {
			self.authenticationSessionCompletionHandler = { [weak self] result in
				self?.isRequestingSFAuthenticationSession = false

				self?.sessionCompletionHandler?(result.map({ _ in true }))
				if case .success(let url) = result {
					self?.application(UIApplication.shared, openUrl: url, sourceApplication: "com.apple", annotation: nil)
				}
				self?.authenticationSession = nil
				self?.authenticationSessionCompletionHandler = nil
			}
		}
	}

	func open(url: URL, sender: IOpenUrlHandler, fromVC: UIViewController?, completion: @escaping SessionCompletionHandler) {

		guard url.scheme?.hasPrefix("http") == true else {
			self.open(url: url, sender: sender, completion: completion)
			return
		}

		if #available(iOS 11.0, *), url.isFBAuthenticationURL {
			self.openURLWithAuthenticationSession(url)
			return
		}

	}

	func openURLWithAuthenticationSession(_ url: URL) {

	}

	func open(url: URL, sender: IOpenUrlHandler, completion: @escaping SessionCompletionHandler) {

	}

	func application(_ application: UIApplication, openUrl: URL, sourceApplication: String, annotation: Any?) {

	}


//	- (void)openURLWithSafariViewController:(NSURL *)url
//	sender:(id<FBSDKURLOpening>)sender
//	fromViewController:(UIViewController *)fromViewController
//	handler:(FBSDKSuccessBlock)handler

}
