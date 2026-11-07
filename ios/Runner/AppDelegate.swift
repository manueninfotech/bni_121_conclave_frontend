import Flutter
import UIKit
import FirebaseMessaging
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var liveActivityChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Hand the APNs device token to FCM explicitly. With the newer implicit-engine
  // AppDelegate, Firebase's automatic swizzling can miss this, so FCM never gets
  // an APNs token — which means topic subscriptions silently fail and NO push
  // ever reaches the device (iOS members got the in-app record but no banner).
  // Setting it here guarantees FCM has it; it's harmless if swizzling already did.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Live Activity bridge: the Dart side (roundStickyDriverProvider) drives the
    // ongoing live-round card on iOS through this channel, the same way it drives
    // the ongoing notification on Android.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ConclaveLiveActivity") {
      let channel = FlutterMethodChannel(
        name: "conclave/live_activity",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        guard #available(iOS 16.2, *) else {
          result(nil) // The content-based ActivityKit APIs need iOS 16.2+.
          return
        }
        switch call.method {
        case "startOrUpdate":
          if let args = call.arguments as? [String: Any] {
            LiveActivityManager.shared.startOrUpdate(args)
          }
          result(nil)
        case "end":
          LiveActivityManager.shared.end()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      liveActivityChannel = channel
    }
  }
}

/// Owns the single live-round Live Activity. Starts it on the first update (only
/// possible while the app is foreground — guaranteed here because the member is
/// locked to the round screen when a round goes live), updates it as the round
/// progresses, and ends it when the round is over.
@available(iOS 16.2, *)
final class LiveActivityManager {
  static let shared = LiveActivityManager()
  private var activity: Activity<RoundActivityAttributes>?

  func startOrUpdate(_ args: [String: Any]) {
    let state = RoundActivityAttributes.RoundState(
      round: (args["round"] as? NSNumber)?.intValue ?? 0,
      totalRounds: (args["totalRounds"] as? NSNumber)?.intValue ?? 0,
      tableNumber: (args["tableNumber"] as? NSNumber)?.intValue ?? 0,
      line: args["line"] as? String ?? "",
      segmentEndEpoch: (args["segmentEndEpoch"] as? NSNumber)?.doubleValue ?? 0,
      paused: (args["paused"] as? NSNumber)?.boolValue ?? false
    )
    let content = ActivityContent(state: state, staleDate: nil)

    if let activity = activity {
      Task { await activity.update(content) }
      return
    }

    // Can only start from the foreground and only if the user has Live
    // Activities enabled; both failures are fine — the next update retries.
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let attributes = RoundActivityAttributes(
      conclaveName: args["conclaveName"] as? String ?? "Conclave"
    )
    do {
      activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
    } catch {
      NSLog("LiveActivity start failed: \(error.localizedDescription)")
    }
  }

  func end() {
    guard let activity = activity else { return }
    self.activity = nil
    Task { await activity.end(nil, dismissalPolicy: .immediate) }
  }
}
