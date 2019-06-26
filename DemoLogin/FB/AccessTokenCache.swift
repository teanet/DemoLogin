import Foundation

class AccessTokenCache {

	struct TokenStorage: Codable {
		let uuid: String
		let token: Token
	}

	private let kFBSDKAccessTokenKeychainKey = "com.facebook.sdk.v4.FBSDKAccessTokenInformationKeychainKey"
	private let kFBSDKAccessTokenUserDefaultsKey = "com.facebook.sdk.v4.FBSDKAccessTokenInformationKey"

	private let store: KeychainStore
	
	init() {
		self.store = KeychainStore.tokenCache
	}

	var fbAccessToken: Token? {
		get {
			let uuid = UserDefaults.standard.string(forKey: kFBSDKAccessTokenUserDefaultsKey)

			if let data = self.store.data(for: kFBSDKAccessTokenKeychainKey),
				let storage = try? JSONDecoder().decode(TokenStorage.self, from: data),
				storage.uuid == uuid {
				return storage.token
			}
			// if the uuid doesn't match (including if there is no uuid in defaults which means uninstalled case)
			// clear the keychain and return nil.
			self.clearCache()
			return nil
		}
		set {
			guard let token = newValue else {
				self.clearCache()
				return
			}

			let uuid = UserDefaults.standard.string(forKey: kFBSDKAccessTokenUserDefaultsKey) ?? {
				let uuid = UUID().uuidString
				UserDefaults.standard.set(uuid, forKey: kFBSDKAccessTokenUserDefaultsKey)
				UserDefaults.standard.synchronize()
				return uuid
			}()

			let storage = TokenStorage(uuid: uuid, token: token)
			let data = try? JSONEncoder().encode(storage)
			self.store.set(data: data, for: kFBSDKAccessTokenKeychainKey, accessibility: .afterFirstUnlockThisDeviceOnly)
		}
	}

	func clearCache() {
		self.store.set(data: nil, for: kFBSDKAccessTokenKeychainKey, accessibility: .afterFirstUnlockThisDeviceOnly)
		UserDefaults.standard.removeObject(forKey: kFBSDKAccessTokenUserDefaultsKey)
		UserDefaults.standard.synchronize()
	}

}
