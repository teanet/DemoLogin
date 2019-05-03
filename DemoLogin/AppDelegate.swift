import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?


	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

		print(">>>>>\((FBSDKLoginError.reserved as NSError).domain)")
		print(">>>>>\(FBURL.facebookURL(with: "m.", path: "asd/asd", query: ["ds": "asd"]))")
		return true

	}

	

}

