import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var osMethodChannel: FlutterMethodChannel?
  private var pendingBitcoinUri: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    osMethodChannel = FlutterMethodChannel(
      name: "app.hotconut.wallet/os",
      binaryMessenger: controller.binaryMessenger
    )

    osMethodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getInitialBitcoinUri" || call.method == "getPendingBitcoinUri" {
        result(self?.pendingBitcoinUri)
        self?.pendingBitcoinUri = nil
      } else if call.method == "setSecureFlag" {
        // iOS는 FLAG_SECURE 직접 대응이 없어 no-op으로 둔다.
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    if let url = launchOptions?[.url] as? URL,
       url.scheme?.lowercased() == "bitcoin" {
      pendingBitcoinUri = url.absoluteString
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    guard url.scheme?.lowercased() == "bitcoin" else {
      return super.application(app, open: url, options: options)
    }

    let uri = url.absoluteString
    pendingBitcoinUri = uri
    osMethodChannel?.invokeMethod("onBitcoinUri", arguments: uri)
    return true
  }
}
