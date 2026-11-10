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

      // v2: hand each activity's push token to Dart, which registers it with
      // the server so round changes can be pushed while the app is suspended.
      if #available(iOS 16.2, *) {
        LiveActivityManager.shared.onPushToken = { [weak channel] token in
          DispatchQueue.main.async {
            channel?.invokeMethod("pushToken", arguments: token)
          }
        }
      }
    }
  }
}

/// Owns the single live-round Live Activity. Starts it on the first update (only
/// possible while the app is foreground — guaranteed here because the member is
/// locked to the round screen when a round goes live), updates it as the round
/// progresses, and ends it when the round is over.
///
/// v2: the activity is requested with a push token, so the server can update it
/// while the app is suspended (round start, referrals, move break, pause,
/// resume, end). The token is reported through [onPushToken]. After an app
/// relaunch the manager reattaches to an activity that is still on screen
/// instead of starting a duplicate.
@available(iOS 16.2, *)
final class LiveActivityManager {
  static let shared = LiveActivityManager()
  private var activity: Activity<RoundActivityAttributes>?
  private var tokenTask: Task<Void, Never>?

  /// Called with the activity's push token (hex) whenever iOS issues one.
  var onPushToken: ((String) -> Void)?

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

    // Reattach to a card still on screen from before an app restart.
    if activity == nil, let existing = Activity<RoundActivityAttributes>.activities.first {
      activity = existing
      observeToken(existing)
    }

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
      let started = try Activity.request(attributes: attributes, content: content, pushType: .token)
      activity = started
      observeToken(started)
    } catch {
      NSLog("LiveActivity start failed: \(error.localizedDescription)")
    }
  }

  private func observeToken(_ activity: Activity<RoundActivityAttributes>) {
    tokenTask?.cancel()
    tokenTask = Task { [weak self] in
      for await data in activity.pushTokenUpdates {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        self?.onPushToken?(hex)
      }
    }
  }

  func end() {
    tokenTask?.cancel()
    tokenTask = nil
    // End ours and any stray card left from an earlier session.
    let all = Activity<RoundActivityAttributes>.activities
    self.activity = nil
    for a in all {
      Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
  }
}
