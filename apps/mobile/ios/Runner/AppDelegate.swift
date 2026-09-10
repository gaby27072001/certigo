import Flutter
import Sentry
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var crashReportingHealthChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Under the `UIScene` lifecycle the window belongs to `SceneDelegate`, not to
  /// this delegate, so `window?.rootViewController` is nil here and can no longer
  /// vend a binary messenger. Registration therefore moves to the implicit-engine
  /// callback, which is the only place that hands us the engine actually backing
  /// the storyboard's `FlutterViewController`.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerCrashReportingHealthChannel(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  /// Backs `SentryNativeIntegrationVerifier` on the Dart side. If this channel is
  /// not registered the verifier throws and the app boots with remote crash
  /// reporting switched off, so the wiring must survive the scene migration.
  private func registerCrashReportingHealthChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.certigo.mobileapp/crash-reporting-health",
      binaryMessenger: binaryMessenger
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
