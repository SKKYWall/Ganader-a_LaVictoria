import Flutter
import UIKit
import flutter_local_notifications // <-- 1. NUEVA IMPORTACIÓN

@main // <-- Conservamos tu etiqueta moderna
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // --- 2. NUEVO: PARA QUE SUENEN CON LA APP ABIERTA ---
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    // ---------------------------------------------------

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}