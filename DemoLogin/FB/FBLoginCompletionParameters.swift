import Foundation

extension String {

	func userIDFromSignedRequest() -> String? {
		guard self.count > 0 else { return nil }

		var userID: String? = nil
		let signatureAndPayload = self.components(separatedBy: ".")
		if signatureAndPayload.count == 2,
			let data = Data(base64Encoded: signatureAndPayload[1]),
			let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
			userID = dictionary["user_id"] as? String
		}
		return userID
	}

}

class FBLoginCompletion {

	let result: Result<FBLoginCompletionParameters, Error>

	init(params: [String: String], appID: String) {

		if let accessToken = params["access_token"], accessToken.count > 0 {
			let grantedPermissionsString = params["granted_scopes"] ?? ""
			let declinedPermissionsString = params["denied_scopes"] ?? ""
			let signedRequest = params["signed_request"] ?? ""
			var userID = params["user_id"] ?? ""
			let permissions = Set(grantedPermissionsString.components(separatedBy: ","))
			let declinedPermissions = Set(declinedPermissionsString.components(separatedBy: ","))

			if userID.count == 0, let userIDFromSignedRequest = signedRequest.userIDFromSignedRequest() {
				userID = userIDFromSignedRequest
			}

			var expirationDate = Date.distantFuture
			if let expirationDateString = params["expires"] ?? params["expires_at"],
				let interval = Double(expirationDateString),
				interval > 0 {
				expirationDate = Date(timeIntervalSince1970: interval)
			} else if let expirationDateString = params["expires_in"],
				let interval = Int(expirationDateString),
				interval > 0 {
				expirationDate = Date(timeIntervalSinceNow: TimeInterval(interval))
			}

			var dataAccessExpirationDate = Date.distantFuture
			if let dataAccessExpirationString = params["data_access_expiration_time"],
				let interval = Double(dataAccessExpirationString),
				interval > 0 {
				dataAccessExpirationDate = Date.init(timeIntervalSince1970: interval)
			}

			let params = FBLoginCompletionParameters(
				accessTokenString: accessToken,
				permissions: permissions,
				declinedPermissions: declinedPermissions,
				appID: appID,
				userID: userID,
				expirationDate: expirationDate,
				dataAccessExpirationDate: dataAccessExpirationDate,
				challenge: nil
			)
			//			NSError *error = nil;
			//			NSDictionary *state = [FBSDKInternalUtility objectForJSONString:parameters[@"state"] error:&error];
			//			_parameters.challenge = [FBSDKUtility URLDecode:state[@"challenge"]];

			self.result = .success(params)
		} else {
			self.result = .failure(FBSDKLoginError.fbErrorFromReturnURLParameters(params))
		}

	}

}

extension NSError.UserInfoKey {

	static let FBSDKErrorDeveloperMessageKey: NSError.UserInfoKey = "com.facebook.sdk:FBSDKErrorDeveloperMessageKey"
	static let FBSDKGraphRequestErrorGraphErrorCodeKey: NSError.UserInfoKey = "com.facebook.sdk:FBSDKGraphRequestErrorGraphErrorCodeKey"
	static let FBSDKGraphRequestErrorKey: NSError.UserInfoKey = "com.facebook.sdk:FBSDKGraphRequestErrorKey"

}

extension FBSDKLoginError {

	static func fbErrorFromReturnURLParameters(_ params: [String: String]) -> Error {

		var userInfo = [NSError.UserInfoKey: Any]()
		userInfo[.FBSDKErrorDeveloperMessageKey] = params["error_message"]
		if userInfo.count > 0 {
			userInfo[.FBSDKErrorDeveloperMessageKey] = params["error"]
			userInfo[.FBSDKGraphRequestErrorGraphErrorCodeKey] = params["error_code"]
			if userInfo[.FBSDKErrorDeveloperMessageKey] != nil {
				userInfo[.FBSDKErrorDeveloperMessageKey] = params["error_reason"]
			}
		}
		userInfo[.FBSDKGraphRequestErrorKey] = FBGraphRequestError.other.rawValue
		return NSError(
			domain: ErrorDomains.FBSDKLoginErrorDomain,
			code: FBSDKLoginError.graphRequestGraphAPI.rawValue,
			userInfo: userInfo as [String: Any]
		)
	}

}

struct FBLoginCompletionParameters {

	let accessTokenString: String
	let permissions: Set<String>
	let declinedPermissions: Set<String>
	let appID: String
	let userID: String
	let expirationDate: Date
	let dataAccessExpirationDate: Date
	let challenge: String?

}

//- (instancetype)init NS_DESIGNATED_INITIALIZER;
//- (instancetype)initWithError:(NSError *)error;
//
//@property (nonatomic, copy, readonly) NSString *accessTokenString;
//
//@property (nonatomic, copy, readonly) NSSet *permissions;
//@property (nonatomic, copy, readonly) NSSet *declinedPermissions;
//
//@property (nonatomic, copy, readonly) NSString *appID;
//@property (nonatomic, copy, readonly) NSString *userID;
//
//@property (nonatomic, copy, readonly) NSError *error;
//
//@property (nonatomic, copy, readonly) NSDate *expirationDate;
//@property (nonatomic, copy, readonly) NSDate *dataAccessExpirationDate;
//
//@property (nonatomic, copy, readonly) NSString *challenge;
