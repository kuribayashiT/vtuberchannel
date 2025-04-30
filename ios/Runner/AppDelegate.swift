import UIKit
import Flutter
// import flutter_local_notifications
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    // FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
    // GeneratedPluginRegistrant.register(with: registry)}
    GeneratedPluginRegistrant.register(with: self)
    // UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
    //   if let error = error {
    //       print("Error requesting notification authorization: \(error.localizedDescription)")
    //   }
    // }
    // TODO: Register youtubeADTableViewCell
    let listTileFactory = ListTileNativeAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
        self, factoryId: "listTile", nativeAdFactory: listTileFactory)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  override func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
    if let message = notification.alertBody {
        let alertController = UIAlertController(title: "通知", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        window?.rootViewController?.present(alertController, animated: true, completion: nil)
    }
}
}
