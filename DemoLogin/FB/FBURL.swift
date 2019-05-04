import Foundation

struct FBURL {

	static let fbApplicationScheme = "fbauth2"
	static var myRedirectScheme: String {
		return "fb\(InfoHelpers.fbAppID)"
	}

	static let oAuthPath = "/dialog/oauth";

	static var redirectUri: String? {
		var cmp = URLComponents()
		cmp.host = "authorize"
		cmp.scheme = self.myRedirectScheme
		return cmp.url?.absoluteString
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

}

struct ErrorDomains {
	static let SFVCCanceledLogin = "com.apple.SafariServices.Authentication"
	static let ASCanceledLogin = "com.apple.AuthenticationServices.WebAuthenticationSession"

	static let FBSDKLoginErrorDomain = "com.facebook.sdk.login"

	static var external = [ SFVCCanceledLogin, ASCanceledLogin ]
}


enum FBSDKLoginError: Int, Error, CustomNSError {
	case reserved = 300
	/// The error code for unknown errors.
	case unknown

	static var errorDomain: String { return ErrorDomains.FBSDKLoginErrorDomain }

}

