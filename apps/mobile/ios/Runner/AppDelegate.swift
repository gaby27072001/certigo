import Flutter
import Sentry
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var crashReportingHealthChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerCrashReportingHealthChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerCrashReportingHealthChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.certigo.mobileapp/crash-reporting-health",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSentryNativeEnabled":
        result(SentrySDK.isEnabled)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    crashReportingHealthChannel = channel
  }
}
