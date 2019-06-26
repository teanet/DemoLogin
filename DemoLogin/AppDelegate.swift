import UIKit

let fbLoginManager = FBLoginManager()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?



	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

		print(">>>>>\((FBSDKLoginError.reserved as NSError).domain)")
		print(">>>>>\(FBURL.facebookURL(with: "m.", path: "asd/asd", query: ["ds": "asd"]))")
		return true

	}

	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
		let result = fbLoginManager.application(app, open: url, options: options)
		print(">>>>>\(result)")
		return true
	}
	

}

