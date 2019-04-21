import UIKit
import FBSDKLoginKit

class ViewController: UIViewController {

	let lm = LoginManager()

	override func viewDidLoad() {
		super.viewDidLoad()

//		[FBSDKSettings setAppID:self.appIDKey];
//		Settings.appID = "1428588254023591"
		///*"FacebookAppId" : "1532375100311572",
		self.lm.logIn(readPermissions: ["email"], from: self) { (result, error) in
			print(">>>>>\(String(describing: result)) \(String(describing: error))")
		}

	}


}

