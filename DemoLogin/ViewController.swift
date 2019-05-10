import UIKit
import FBSDKLoginKit

class ViewController: UIViewController {

	let lm = LoginManager()
	let lm2 = FBLoginManager()

	override func viewDidLoad() {
		super.viewDidLoad()

		self.navigationItem.rightBarButtonItems = [
			UIBarButtonItem.init(title: "FB", style: .plain, target: self, action: #selector(self.fbLogin)),
			UIBarButtonItem.init(title: "MY", style: .plain, target: self, action: #selector(self.myLogin)),
		]


//		[FBSDKSettings setAppID:self.appIDKey];
//		Settings.appID = "1428588254023591"
		///*"FacebookAppId" : "1532375100311572",

	}

	@objc func myLogin() {
		self.lm2.login(permissions: [.email], sourceVC: self) { (result) in
		}
	}

	@objc func fbLogin() {
		self.lm.logIn(readPermissions: ["email"], from: self) { (result, error) in
			print(">>>>>\(String(describing: result)) \(String(describing: error))")
		}

	}


}

