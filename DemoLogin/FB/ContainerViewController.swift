import UIKit

protocol ContainerViewControllerDelegate: AnyObject {

	func viewController(_ vc: ContainerViewController, didDisappearAnimated animated: Bool)

}

final class ContainerViewController: UIViewController {

	weak var delegate: ContainerViewControllerDelegate?

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		self.delegate?.viewController(self, didDisappearAnimated: animated)
	}

	func display(child: UIViewController) {
		self.addChild(child)
		child.view.frame = self.view.bounds
		child.didMove(toParent: self)
	}

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		self.children.forEach {
			$0.view.frame = self.view.bounds
		}
	}

}
