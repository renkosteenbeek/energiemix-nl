import UIKit
import Capacitor

class BounceViewController: CAPBridgeViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let light = UIColor(red: 250/255, green: 250/255, blue: 247/255, alpha: 1)
        let dark  = UIColor(red: 20/255, green: 20/255, blue: 19/255, alpha: 1)
        let bg = UIColor { $0.userInterfaceStyle == .dark ? dark : light }
        view.backgroundColor = bg
        webView?.backgroundColor = bg
        webView?.scrollView.backgroundColor = bg
        webView?.isOpaque = false

        webView?.scrollView.bounces = true
        webView?.scrollView.alwaysBounceVertical = true

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        webView?.scrollView.refreshControl = refreshControl
    }

    @objc private func handleRefresh(_ sender: UIRefreshControl) {
        webView?.evaluateJavaScript("window.location.reload()") { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                sender.endRefreshing()
            }
        }
    }
}
