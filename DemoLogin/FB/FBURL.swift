import Foundation

struct FBURL {

	static let fbApplicationScheme = "fbauth2"
	static var myRedirectScheme: String {
		return "fb\(InfoHelpers.fbAppID)"
	}

	static let oAuthPath = "/dialog/oauth";

	static var redirectUri: String {
		var cmp = URLComponents()
		cmp.host = "authorize"
		cmp.scheme = self.myRedirectScheme
		return cmp.url!.absoluteString
	}

	static func canOpenUrl(_ url: URL, sourceApplication: String?) -> Bool {
		// verify the URL is intended as a callback for the SDK's log in
		let isFacebookURL = url.scheme?.hasPrefix(FBURL.myRedirectScheme) == true &&
			url.host == "authorize"

		let isExpectedSourceApplication =
			sourceApplication?.hasPrefix("com.facebook") == true  ||
				sourceApplication?.hasPrefix("com.apple") == true ||
				sourceApplication?.hasPrefix("com.burbn") == true
		return isFacebookURL && isExpectedSourceApplication
	}

	static func facebookURL(with prefix: String, path: String, query: [String: String]) -> URL {
		let host = prefix + "facebook.com"
		let version = "v3.2"
		var path = (version as NSString).appendingPathComponent(path)
		if !path.hasPrefix("/") {
			path = "/" + path
		}

		var cmp = URLComponents()
		cmp.scheme = "https"
		cmp.host = host
		cmp.path = path
		cmp.queryItems = query.map({ URLQueryItem(name: $0.key, value: $0.value) })
		return cmp.url!
	}

//	+ (NSURL *)facebookURLWithHostPrefix:(NSString *)hostPrefix
//	path:(NSString *)path
//	queryParameters:(NSDictionary *)queryParameters
//	defaultVersion:(NSString *)defaultVersion
//	error:(NSError *__autoreleasing *)errorRef
//	{
//	if (hostPrefix.length && ![hostPrefix hasSuffix:@"."]) {
//	hostPrefix = [hostPrefix stringByAppendingString:@"."];
//	}
//
//	NSString *host = @"facebook.com";
//	NSString *domainPart = [FBSDKSettings facebookDomainPart];
//	if (domainPart.length) {
//	host = [[NSString alloc] initWithFormat:@"%@.%@", domainPart, host];
//	}
//	host = [NSString stringWithFormat:@"%@%@", hostPrefix ?: @"", host ?: @""];
//
//	NSString *version = (defaultVersion.length > 0) ? defaultVersion : [FBSDKSettings graphAPIVersion];
//	if (version.length) {
//	version = [@"/" stringByAppendingString:version];
//	}
//
//	if (path.length) {
//	NSScanner *versionScanner = [[NSScanner alloc] initWithString:path];
//	if ([versionScanner scanString:@"/v" intoString:NULL] &&
//	[versionScanner scanInteger:NULL] &&
//	[versionScanner scanString:@"." intoString:NULL] &&
//	[versionScanner scanInteger:NULL]) {
//	[FBSDKLogger singleShotLogEntry:FBSDKLoggingBehaviorDeveloperErrors
//	logEntry:[NSString stringWithFormat:@"Invalid Graph API version:%@, assuming %@ instead",
//	version,
//	[FBSDKSettings graphAPIVersion]]];
//	version = nil;
//	}
//	if (![path hasPrefix:@"/"]) {
//	path = [@"/" stringByAppendingString:path];
//	}
//	}
//	path = [[NSString alloc] initWithFormat:@"%@%@", version ?: @"", path ?: @""];
//
//	return [self URLWithScheme:@"https"
//	host:host
//	path:path
//	queryParameters:queryParameters
//	error:errorRef];
//	}

}

extension URL {

	var isFBAuthenticationURL: Bool {
		return self.path.hasSuffix(FBURL.oAuthPath)
	}

	func fbLoginQuery() -> [String: String] {
		guard self.absoluteString.hasPrefix(FBURL.redirectUri) else { return [:] }

		var params = [String: String]()
		if let queryParams = self.query?.dictionaryFromQuery() {
			params.merge(queryParams) { first, _ in first }
		}
		if let fragmentParams = self.fragment?.dictionaryFromQuery() {
			params.merge(fragmentParams) { first, _ in first }
		}
		return params
	}

}

extension String {

	func dictionaryFromQuery() -> [String: String] {
		var dict = [String: String]()

		let components = self.components(separatedBy: "&")
		for component in components {

			let keyValue = component.components(separatedBy: "=")
			if keyValue.count == 2,
				let key = keyValue[0].urlDecode(),
				let value = keyValue[1].urlDecode() {
				dict[key] = value
			}
		}
		return dict
	}

	func urlDecode() -> String? {
		let string = self.replacingOccurrences(of: "+", with: " ")
		return string.removingPercentEncoding
	}

}

struct ErrorDomains {
	static let SFVCCanceledLogin = "com.apple.SafariServices.Authentication"
	static let ASCanceledLogin = "com.apple.AuthenticationServices.WebAuthenticationSession"

	static let FBSDKLoginErrorDomain = "com.facebook.sdk.login"

	static var external = [ SFVCCanceledLogin, ASCanceledLogin ]
}


enum FBSDKLoginError: Int, Error, CustomNSError {
	case reserved = 300

	/**
	The login response was missing a valid challenge string.
	*/
	case badChallenge

	/// The error code for unknown errors.
	case unknown

	/**
	The Graph API returned an error.

	See below for useful userInfo keys (beginning with FBSDKGraphRequestError*)
	*/
	case graphRequestGraphAPI
	
	static var errorDomain: String { return ErrorDomains.FBSDKLoginErrorDomain }

}

enum FBGraphRequestError: Int {
	/** The default error category that is not known to be recoverable. Check `FBSDKLocalizedErrorDescriptionKey` for a user facing message. */
	case other = 0
	/** Indicates the error is temporary (such as server throttling). While a recoveryAttempter will be provided with the error instance, the attempt is guaranteed to succeed so you can simply retry the operation if you do not want to present an alert.  */
	case transient = 1
	/** Indicates the error can be recovered (such as requiring a login). A recoveryAttempter will be provided with the error instance that can take UI action. */
	case recoverable = 2
}
