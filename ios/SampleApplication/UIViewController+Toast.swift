import UIKit

extension UIViewController {
    func showToast(_ message: String, duration: TimeInterval = 2.0) {
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 14)
        toastLabel.text = message
        toastLabel.numberOfLines = 0
        toastLabel.alpha = 0.0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true

        let maxSize = CGSize(width: view.bounds.width - 40, height: view.bounds.height)
        let expectedSize = toastLabel.sizeThatFits(maxSize)
        toastLabel.frame = CGRect(
            x: (view.bounds.width - expectedSize.width - 20) / 2,
            y: view.bounds.height - 100,
            width: expectedSize.width + 20,
            height: expectedSize.height + 20
        )

        view.addSubview(toastLabel)

        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0.0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
}
