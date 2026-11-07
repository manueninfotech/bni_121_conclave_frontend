//
//  ConclaveLiveActivity.swift
//  ConclaveWidgets
//
//  The live-round card: lock screen / banner + Dynamic Island. Mirrors the
//  Android ongoing "sticky" notification — round · table · live countdown, with
//  the current speaker during the round and the move instruction between rounds.
//

import ActivityKit
import SwiftUI
import WidgetKit

private let brand = Color(red: 0.77, green: 0.07, blue: 0.19) // #C41230

/// The self-counting countdown, or a frozen value when the round is paused.
private struct Countdown: View {
  let state: RoundActivityAttributes.RoundState
  var font: Font = .title2.weight(.bold)

  var body: some View {
    Group {
      if state.paused {
        Text("Paused")
      } else if state.segmentEnd > Date() {
        Text(timerInterval: Date()...state.segmentEnd, countsDown: true)
          .monospacedDigit()
          .multilineTextAlignment(.trailing)
      } else {
        Text("0:00").monospacedDigit()
      }
    }
    .font(font)
    .foregroundStyle(brand)
  }
}

struct ConclaveLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RoundActivityAttributes.self) { context in
      // Lock screen / banner.
      LockScreenView(context: context)
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Text("ROUND \(context.state.round)/\(context.state.totalRounds)")
              .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Text("Table \(context.state.tableNumber)")
              .font(.headline)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          Countdown(state: context.state)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.line)
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(2)
        }
      } compactLeading: {
        Text("T\(context.state.tableNumber)").font(.caption.weight(.bold))
      } compactTrailing: {
        Countdown(state: context.state, font: .caption.weight(.bold))
      } minimal: {
        Text("R\(context.state.round)").font(.caption2.weight(.bold))
      }
      .widgetURL(URL(string: "conclave://active"))
      .keylineTint(brand)
    }
  }
}

private struct LockScreenView: View {
  let context: ActivityViewContext<RoundActivityAttributes>

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("ROUND \(context.state.round) OF \(context.state.totalRounds) · TABLE \(context.state.tableNumber)")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Text(context.state.line)
          .font(.headline)
          .foregroundStyle(.white)
          .lineLimit(2)
        Text(context.attributes.conclaveName)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 8)
      Countdown(state: context.state, font: .system(size: 30, weight: .bold, design: .rounded))
        .fixedSize()
    }
    .padding(16)
  }
}
