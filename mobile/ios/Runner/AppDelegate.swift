import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let methodChannel = FlutterMethodChannel(
      name: "recovery_companion/recovery_backup_protector",
      binaryMessenger: engineBridge.binaryMessenger
    )

    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handleBackupProtectionCall(call: call, result: result)
    }
  }

  private func handleBackupProtectionCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "excludeFromBackup" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard let args = call.arguments as? [String: Any],
          let rawPath = args["path"] as? String,
          !rawPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result(FlutterError(
        code: "INVALID_PATH",
        message: "Recovery file path is missing or invalid.",
        details: nil
      ))
      return
    }

    let fileURL = URL(fileURLWithPath: rawPath)

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      result(FlutterError(
        code: "FILE_NOT_FOUND",
        message: "Recovery file does not exist.",
        details: fileURL.path
      ))
      return
    }

    do {
      var resourceValues = URLResourceValues()
      resourceValues.isExcludedFromBackup = true

      var mutableURL = fileURL
      try mutableURL.setResourceValues(resourceValues)
      result(true)
    } catch {
      result(FlutterError(
        code: "BACKUP_EXCLUSION_FAILED",
        message: "Could not mark the recovery file as excluded from backup.",
        details: error.localizedDescription
      ))
    }
  }
}
