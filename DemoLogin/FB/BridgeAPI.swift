import UIKit
import AuthenticationServices
import SafariServices

protocol AuthenticationSession: AnyObject {
//		- (instancetype)initWithURL:(NSURL *)URL callbackURLScheme:(nullable NSString *)callbackURLScheme completionHandler:(FBSDKAuthenticationCompletionHandler)completionHandler;
	func start() -> Bool
	func cancel()
}

@available(iOS 11.0, *)
extension SFAuthenticationSession: AuthenticationSession {
}

@available(iOS 12.0, *)
extension ASWebAuthenticationSession: AuthenticationSession {
}

final class BridgeAPI: NSObject {

	typealias SessionCompletionHandler = (Result<Bool, Error>) -> Void
	typealias AuthenticationCompletionHandler = (Result<URL, Error>) -> Void

	private var expectingBackground = false
	private var isRequestingSFAuthenticationSession = false
	private var pendingURLOpen: IOpenUrlHandler?
	private var authenticationSessionCompletionHandler: AuthenticationCompletionHandler?
	private var authenticationSession: AuthenticationSession?
	private var safariViewController: SFSafariViewController?
	private var pendingRequest: BridgeAPIRequest?
	private var pendingRequestCompletionBlock: BridgeAPIResponseBlock?
	private var isDismissingSafariViewController = false

	private var sessionCompletionHandler: SessionCompletionHandler? {
		didSet {
			self.authenticationSessionCompletionHandler = { [weak self] result in
				self?.isRequestingSFAuthenticationSession = false

				self?.sessionCompletionHandler?(result.map({ _ in true }))
				if case .success(let url) = result {
					self?.application(UIApplication.shared, openUrl: url, options: [.sourceApplication: "com.apple"])
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

		guard let parent = fromVC ?? UIApplication.topMostViewController(),
			var cmp = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			self.open(url: url, sender: sender, completion: completion)
			return
		}

		var queryItems = cmp.queryItems ?? []
		queryItems.append(URLQueryItem(name: "sfvc", value: "1"))
		cmp.queryItems = queryItems
		let url = cmp.url!

		if let transitionCoordinator = parent.transitionCoordinator {
			// Wait until the transition is finished before presenting SafariVC to avoid a blank screen.
			transitionCoordinator.animate(alongsideTransition: nil) { [weak self] (_) in
				self?.presentSafariVC(with: url, parent: parent, completion: completion)
			}
		} else {
			self.presentSafariVC(with: url, parent: parent, completion: completion)
		}
	}

	private func presentSafariVC(with url: URL, parent: UIViewController, completion: @escaping SessionCompletionHandler) {
		let container = ContainerViewController()
		container.delegate = self

		let safariVC = SFSafariViewController(url: url)
		// Disable dismissing with edge pan gesture
		safariVC.modalPresentationStyle = .overFullScreen
		safariVC.delegate = self
		container.display(child: safariVC)
		self.safariViewController = safariVC
		parent.present(container, animated: true, completion: nil)
	}

	@available(iOS 11.0, *)
	private func openURLWithAuthenticationSession(_ url: URL) {

		self.authenticationSession?.cancel()

		if #available(iOS 12.0, *) {
			self.authenticationSession = ASWebAuthenticationSession(url: url, callbackURLScheme: FBURL.myRedirectScheme) { (url, error) in
				if let url = url {
					self.authenticationSessionCompletionHandler?(.success(url))
				} else {
					let error = error ?? NSError(domain: ErrorDomains.ASCanceledLogin, code: -1, userInfo: nil)
					self.authenticationSessionCompletionHandler?(.failure(error))
				}
			}
		} else {
			self.authenticationSession = SFAuthenticationSession(url: url, callbackURLScheme: FBURL.myRedirectScheme, completionHandler: { (url, error) in
				if let url = url {
					self.authenticationSessionCompletionHandler?(.success(url))
				} else {
					let error = error ?? NSError(domain: ErrorDomains.FBSDKLoginErrorDomain, code: -1, userInfo: nil)
					self.authenticationSessionCompletionHandler?(.failure(error))
				}
			})
		}
		self.isRequestingSFAuthenticationSession = true
		_ = self.authenticationSession?.start()
	}

	func open(url: URL, sender: IOpenUrlHandler, completion: @escaping SessionCompletionHandler) {
		self.expectingBackground = true
		self.pendingURLOpen = sender
		// Dispatch openURL calls to prevent hangs if we're inside the current app delegate's openURL flow already
		DispatchQueue.main.async {
			UIApplication.shared.open(url, options: [:], completionHandler: { (success) in
				completion(.success(success))
			})
		}
	}

	@discardableResult
	func application(_ application: UIApplication, openUrl: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
		guard let pendingURLOpen = self.pendingURLOpen else { return false }

		let completePendingOpenURLBlock = { [weak self] in
			self?.pendingURLOpen = nil
			_ = pendingURLOpen.application(application, open: openUrl, options: options)
			self?.isDismissingSafariViewController = false
		}

		if let safariVC = self.safariViewController {
			self.isDismissingSafariViewController = true
			safariVC.presentingViewController?.dismiss(animated: true, completion: completePendingOpenURLBlock)
		} else {
			self.authenticationSession?.cancel()
			self.authenticationSession = nil
			completePendingOpenURLBlock()
		}

		if pendingURLOpen.canOpenURL(openUrl, application: application, options: options) {
			return true
		}

		if self.handleBridgeAPIResponseURL(openUrl, options: options) {
			return true
		}

		return false
	}

	private func handleBridgeAPIResponseURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
		return false
		//	- (BOOL)_handleBridgeAPIResponseURL:(NSURL *)responseURL sourceApplication:(NSString *)sourceApplication
		//	{
		//	FBSDKBridgeAPIRequest *request = _pendingRequest;
		//	FBSDKBridgeAPIResponseBlock completionBlock = _pendingRequestCompletionBlock;
		//	_pendingRequest = nil;
		//	_pendingRequestCompletionBlock = NULL;
		//	if (![responseURL.scheme isEqualToString:[FBSDKInternalUtility appURLScheme]]) {
		//	return NO;
		//	}
		//	if (![responseURL.host isEqualToString:@"bridge"]) {
		//	return NO;
		//	}
		//	if (!request) {
		//	return NO;
		//	}
		//	if (!completionBlock) {
		//	return YES;
		//	}
		//	NSError *error;
		//	FBSDKBridgeAPIResponse *response = [FBSDKBridgeAPIResponse bridgeAPIResponseWithRequest:request
		//	responseURL:responseURL
		//	sourceApplication:sourceApplication
		//	error:&error];
		//	if (response) {
		//	completionBlock(response);
		//	return YES;
		//	} else if (error) {
		//	completionBlock([FBSDKBridgeAPIResponse bridgeAPIResponseWithRequest:request error:error]);
		//	return YES;
		//	} else {
		//	return NO;
		//	}
		//	}
	}


	private func cancelBridgeRequest() {
		if let pendingRequest = self.pendingRequest, let pendingRequestCompletionBlock = self.pendingRequestCompletionBlock {
			let response = BridgeAPIResponse.cancelled(with: pendingRequest)
			pendingRequestCompletionBlock(response)
		}
		self.pendingRequest = nil
		self.pendingRequestCompletionBlock = nil
	}

}

extension BridgeAPI: SFSafariViewControllerDelegate {

	// This means the user tapped "Done" which we should treat as a cancellation.
	func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
		if let pendingURLOpen = self.pendingURLOpen {
			self.pendingURLOpen = nil
			_ = pendingURLOpen.application(UIApplication.shared, open: URL(fileURLWithPath: ""), options: [:])
		}
		self.cancelBridgeRequest()
		self.safariViewController = nil
	}

}

extension BridgeAPI: ContainerViewControllerDelegate {

	func viewController(_ vc: ContainerViewController, didDisappearAnimated animated: Bool) {
		if let safariViewController = self.safariViewController {
			self.safariViewControllerDidFinish(safariViewController)
		}
	}

}
