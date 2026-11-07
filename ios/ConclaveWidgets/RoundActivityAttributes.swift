//
//  RoundActivityAttributes.swift
//  Conclave
//
//  The live-round Live Activity's data contract. This ONE type must be compiled
//  into BOTH targets — the Runner app (which starts/updates/ends the activity)
//  and the ConclaveWidgets extension (which renders it) — because ActivityKit
//  matches an activity to its widget by this exact attributes type. In Xcode,
//  tick Target Membership for BOTH "Runner" and "ConclaveWidgetsExtension" on
//  this file.
//

import ActivityKit
import Foundation

struct RoundActivityAttributes: ActivityAttributes {
  public typealias ContentState = RoundState

  // Fixed for the life of the activity.
  var conclaveName: String

  public struct RoundState: Codable, Hashable {
    /// Current round and total, e.g. "Round 2 of 5".
    var round: Int
    var totalRounds: Int
    /// The table the member is at right now.
    var tableNumber: Int
    /// One-line status: who's speaking, or the move instruction ("Move to
    /// Table 5") during the transition between rounds.
    var line: String
    /// Wall-clock instant this segment's countdown reaches zero, as seconds
    /// since 1970. The widget runs a self-counting timer to it, so the
    /// countdown stays live even while the phone is pocketed and the app is
    /// suspended.
    var segmentEndEpoch: Double
    /// Paused rounds freeze the countdown.
    var paused: Bool

    var segmentEnd: Date { Date(timeIntervalSince1970: segmentEndEpoch) }
  }
}
