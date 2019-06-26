import Foundation

enum ItemClass: RawRepresentable, CustomStringConvertible {
	case genericPassword
	case internetPassword

	public init?(rawValue: String) {
		switch rawValue {
		case String(kSecClassGenericPassword):
			self = .genericPassword
		case String(kSecClassInternetPassword):
			self = .internetPassword
		default:
			return nil
		}
	}

	public var rawValue: String {
		switch self {
			case .genericPassword:
				return String(kSecClassGenericPassword)
			case .internetPassword:
				return String(kSecClassInternetPassword)
		}
	}

	public var description: String {
		switch self {
			case .genericPassword:
				return "GenericPassword"
			case .internetPassword:
				return "InternetPassword"
		}
	}
}

final class KeychainStore {

	static let tokenCache = KeychainStore.init(prefix: "com.facebook.sdk.tokencache")
	static let loginManager = KeychainStore.init(prefix: "com.facebook.sdk.loginmanager")

	private let Class = String(kSecClass)
	private let AttributeSynchronizable = String(kSecAttrSynchronizable)
	private let AttributeAccount = String(kSecAttrAccount)
	private let AttributeService = String(kSecAttrService)
	private let AttributeAccessGroup = String(kSecAttrAccessGroup)
	private let ValueData = String(kSecValueData)
	private let ReturnData = String(kSecReturnData)
	private let AttributeAccessible = String(kSecAttrAccessible)
	private let MatchLimit = String(kSecMatchLimit)
	private let MatchLimitOne = kSecMatchLimitOne

	private let SynchronizableAny = kSecAttrSynchronizableAny

	private let service: String
	private let accessGroup: String?
	private init(service: String, accessGroup: String?) {
		self.service = service
		self.accessGroup = accessGroup
	}

	private convenience init(prefix: String) {
		let service = "\(prefix).\(Bundle.main.bundleIdentifier!)"
		self.init(service: service, accessGroup: nil)
	}

	@discardableResult
	func set(data: Data?, for key: String, accessibility: Accessibility) -> Bool {
		guard !key.isEmpty else { return false }

		#if targetEnvironment(simulator)
		print("Falling back to storing access token in NSUserDefaults because of simulator bug")
		UserDefaults.standard.set(data, forKey: key)
		return UserDefaults.standard.synchronize()
		#else

		var query = self.query(for: key)
		var status: OSStatus
		if let data = data {
			var attributesToUpdate = [String: Any]()
			attributesToUpdate[ValueData] = data
			status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
			if status == errSecItemNotFound {
				query[AttributeAccessible] = accessibility
				query[ValueData] = data
				status = SecItemAdd(query as CFDictionary, nil)
			}
		} else {
			status = SecItemDelete(query as CFDictionary)
			if (status == errSecItemNotFound) {
				status = errSecSuccess;
			}
		}
		return status == errSecSuccess
		#endif
	}

	func data(for key: String) -> Data? {
		guard !key.isEmpty else { return nil }

		#if targetEnvironment(simulator)
		print("Falling back to storing access token in NSUserDefaults because of simulator bug")
		return UserDefaults.standard.data(forKey: key)
		#else
		var query = self.query(for: key)
		query[ReturnData] = kCFBooleanTrue
		query[MatchLimit] = MatchLimitOne

		var result: AnyObject?
		let status = SecItemCopyMatching(query as CFDictionary, &result)

		switch status {
			case errSecSuccess:
				guard let data = result as? Data else {
					return nil
				}
				return data
			case errSecItemNotFound:
				return nil
			default:
				return nil
		}
		#endif
	}

	@discardableResult
	func set(string: String?, for key: String, accessibility: Accessibility) -> Bool {
		let data = string?.data(using: .utf8)
		return self.set(data: data, for: key, accessibility: accessibility)
	}

	func string(for key: String) -> String? {
		guard let data = self.data(for: key) else { return nil }
		return String(data: data, encoding: .utf8)
	}

	private func query(for key: String) -> [String: Any] {
		var query = [String: Any]()
		query[Class] = ItemClass.genericPassword.rawValue
		query[AttributeSynchronizable] = SynchronizableAny
		query[AttributeService] = self.service
		query[AttributeAccount] = key
		#if targetEnvironment(simulator)
		#else
		if let accessGroup = self.accessGroup {
			query[AttributeAccessGroup] = accessGroup
		}
		#endif
		return query
	}

}


public enum Accessibility: RawRepresentable, CustomStringConvertible {
	/**
	Item data can only be accessed
	while the device is unlocked. This is recommended for items that only
	need be accesible while the application is in the foreground. Items
	with this attribute will migrate to a new device when using encrypted
	backups.
	*/
	case whenUnlocked

	/**
	Item data can only be
	accessed once the device has been unlocked after a restart. This is
	recommended for items that need to be accesible by background
	applications. Items with this attribute will migrate to a new device
	when using encrypted backups.
	*/
	case afterFirstUnlock

	/**
	Item data can always be accessed
	regardless of the lock state of the device. This is not recommended
	for anything except system use. Items with this attribute will migrate
	to a new device when using encrypted backups.
	*/
	case always

	/**
	Item data can
	only be accessed while the device is unlocked. This class is only
	available if a passcode is set on the device. This is recommended for
	items that only need to be accessible while the application is in the
	foreground. Items with this attribute will never migrate to a new
	device, so after a backup is restored to a new device, these items
	will be missing. No items can be stored in this class on devices
	without a passcode. Disabling the device passcode will cause all
	items in this class to be deleted.
	*/
	@available(iOS 8.0, OSX 10.10, *)
	case whenPasscodeSetThisDeviceOnly

	/**
	Item data can only
	be accessed while the device is unlocked. This is recommended for items
	that only need be accesible while the application is in the foreground.
	Items with this attribute will never migrate to a new device, so after
	a backup is restored to a new device, these items will be missing.
	*/
	case whenUnlockedThisDeviceOnly

	/**
	Item data can
	only be accessed once the device has been unlocked after a restart.
	This is recommended for items that need to be accessible by background
	applications. Items with this attribute will never migrate to a new
	device, so after a backup is restored to a new device these items will
	be missing.
	*/
	case afterFirstUnlockThisDeviceOnly

	/**
	Item data can always
	be accessed regardless of the lock state of the device. This option
	is not recommended for anything except system use. Items with this
	attribute will never migrate to a new device, so after a backup is
	restored to a new device, these items will be missing.
	*/
	case alwaysThisDeviceOnly


	public init?(rawValue: String) {
		switch rawValue {
		case String(kSecAttrAccessibleWhenUnlocked):
				self = .whenUnlocked
			case String(kSecAttrAccessibleAfterFirstUnlock):
				self = .afterFirstUnlock
			case String(kSecAttrAccessibleAlways):
				self = .always
			case String(kSecAttrAccessibleWhenUnlockedThisDeviceOnly):
				self = .whenUnlockedThisDeviceOnly
			case String(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly):
				self = .afterFirstUnlockThisDeviceOnly
			case String(kSecAttrAccessibleAlwaysThisDeviceOnly):
				self = .alwaysThisDeviceOnly
			default:
				return nil
		}
	}

	public var rawValue: String {
		switch self {
			case .whenUnlocked:
				return String(kSecAttrAccessibleWhenUnlocked)
			case .afterFirstUnlock:
				return String(kSecAttrAccessibleAfterFirstUnlock)
			case .always:
				return String(kSecAttrAccessibleAlways)
			case .whenPasscodeSetThisDeviceOnly:
				if #available(OSX 10.10, *) {
					return String(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
				} else {
					fatalError("'Accessibility.WhenPasscodeSetThisDeviceOnly' is not available on this version of OS.")
				}
			case .whenUnlockedThisDeviceOnly:
				return String(kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
			case .afterFirstUnlockThisDeviceOnly:
				return String(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
			case .alwaysThisDeviceOnly:
				return String(kSecAttrAccessibleAlwaysThisDeviceOnly)
		}
	}

	public var description: String {
		switch self {
			case .whenUnlocked:
				return "WhenUnlocked"
			case .afterFirstUnlock:
				return "AfterFirstUnlock"
			case .always:
				return "Always"
			case .whenPasscodeSetThisDeviceOnly:
				return "WhenPasscodeSetThisDeviceOnly"
			case .whenUnlockedThisDeviceOnly:
				return "WhenUnlockedThisDeviceOnly"
			case .afterFirstUnlockThisDeviceOnly:
				return "AfterFirstUnlockThisDeviceOnly"
			case .alwaysThisDeviceOnly:
				return "AlwaysThisDeviceOnly"
		}
	}

}
