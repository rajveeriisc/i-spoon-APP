import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set notification delegate so foreground notifications display correctly
    UNUserNotificationCenter.current().delegate = self

    // Register workmanager background task identifiers with BGTaskScheduler.
    // This MUST be called before application(_:didFinishLaunchingWithOptions:) returns.
    // Each identifier listed here must also appear in Info.plist BGTaskSchedulerPermittedIdentifiers.
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "daily-sync-11pm", frequency: nil)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
