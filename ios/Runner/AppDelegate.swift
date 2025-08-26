import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up deep link method channel
    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not type FlutterViewController")
    }
    
    methodChannel = FlutterMethodChannel(name: "deep_link_channel", binaryMessenger: controller.binaryMessenger)
    methodChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getInitialLink" {
        result(self?.getInitialLink())
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if url.scheme == "zippyapp" {
      methodChannel?.invokeMethod("onDeepLink", arguments: url.absoluteString)
      return true
    }
    return super.application(app, open: url, options: options)
  }
  
  private func getInitialLink() -> String? {
    // This would be called if the app was launched via deep link
    // For now, return nil as we handle it in the open URL method
    return nil
  }
}
