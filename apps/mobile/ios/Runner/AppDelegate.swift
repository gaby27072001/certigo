import Flutter
import Sentry
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var crashReportingHealthChannel: FlutterMethodChannel?
  private var accessibilityChannel: FlutterMethodChannel?
  private var notificationSettingsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
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
    registerAccessibilityChannel(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    let channel = FlutterMethodChannel(
      name: "com.certigo.mobileapp/notifications",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "openSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
    }
    notificationSettingsChannel = channel
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

  /// Relaie `Reduce Transparency` au thème Prism.
  ///
  /// Flutter n'expose pas ce réglage : `MediaQueryData` déclare `highContrast`,
  /// `boldText`, `accessibleNavigation`, `disableAnimations`, `invertColors` et
  /// `onOffSwitchLabels`, mais aucun équivalent de
  /// `UIAccessibility.isReduceTransparencyEnabled`. Sans ce canal, un
  /// utilisateur qui demande explicitement à iOS de supprimer la translucidité
  /// continue de voir deux `BackdropFilter` — la barre d'onglets et l'entête.
  ///
  /// Le canal fait deux choses, et les deux sont nécessaires : il répond à la
  /// question au démarrage, et il **pousse** le changement quand l'utilisateur
  /// bascule le réglage pendant que l'application tourne. Sans la notification,
  /// le réglage ne prendrait effet qu'au prochain lancement.
  private func registerAccessibilityChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.certigo.mobileapp/accessibility",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isReduceTransparencyEnabled":
        result(UIAccessibility.isReduceTransparencyEnabled)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    accessibilityChannel = channel

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(reduceTransparencyStatusDidChange),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil
    )
  }

  @objc private func reduceTransparencyStatusDidChange() {
    accessibilityChannel?.invokeMethod(
      "reduceTransparencyChanged",
      arguments: UIAccessibility.isReduceTransparencyEnabled
    )
  }
}
