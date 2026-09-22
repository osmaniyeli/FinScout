import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private var privacyView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // iOS App Switcher & Snapshotting gizlilik kalkanı (Finansal Veri Koruması)
  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    if let window = self.window {
      let blurEffect = UIBlurEffect(style: .dark)
      let blurView = UIVisualEffectView(effect: blurEffect)
      blurView.frame = window.bounds
      blurView.tag = 9999
      window.addSubview(blurView)
      self.privacyView = blurView
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    self.privacyView?.removeFromSuperview()
    self.privacyView = nil
  }
}
