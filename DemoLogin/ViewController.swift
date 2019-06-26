import UIKit
import FBSDKLoginKit

class ViewController: UIViewController {

	let lm = LoginManager()

	override func viewDidLoad() {
		super.viewDidLoad()

		self.navigationItem.rightBarButtonItems = [
			UIBarButtonItem.init(title: "FB", style: .plain, target: self, action: #selector(self.fbLogin)),
			UIBarButtonItem.init(title: "MY", style: .plain, target: self, action: #selector(self.myLogin)),
		]
	}

	@objc func myLogin() {
		fbLoginManager.login(permissions: [.email], sourceVC: self) { (result) in
		}
	}

	@objc func fbLogin() {
		self.lm.logIn(readPermissions: ["email"], from: self) { (result, error) in
			print(">>>>>\(String(describing: result)) \(String(describing: error))")
		}

	}


}

