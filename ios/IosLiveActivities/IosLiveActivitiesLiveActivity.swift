//
//  IosLiveActivitiesLiveActivity.swift
//  IosLiveActivities
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attributes

struct IosLiveActivitiesAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var emoji: String
    }
    var name: String
}

// LiveActivitiesAppAttributes is the type the live_activities Flutter plugin
// always uses. All data is exchanged via UserDefaults keyed by UUID prefix.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    typealias LiveDeliveryData = ContentState
    struct ContentState: Codable, Hashable {}
    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String { "\(id)_\(key)" }
}

// MARK: - Shared UserDefaults

let sharedDefault = UserDefaults(suiteName: "group.iosLiveActivities")!

// MARK: - Timer widget (LiveActivitiesAppAttributes)

struct TimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            TimerBannerView(attr: context.attributes)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            let attr = context.attributes
            let paused = sharedDefault.bool(forKey: attr.prefixedKey("paused"))
            let startMs = sharedDefault.double(forKey: attr.prefixedKey("startTime"))
            let origin = Date(timeIntervalSince1970: startMs / 1000)
            let frozenSecs = sharedDefault.integer(forKey: attr.prefixedKey("elapsedSeconds"))

            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    if paused {
                        Text(formatSeconds(frozenSecs))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                    } else {
                        Text(origin, style: .timer)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Label(
                        paused ? "Paused" : "Running",
                        systemImage: paused ? "pause.circle.fill" : "timer"
                    )
                    .font(.caption)
                    .foregroundStyle(paused ? .orange : .green)
                }
            } compactLeading: {
                Image(systemName: paused ? "pause.fill" : "timer")
                    .foregroundStyle(paused ? .orange : .green)
            } compactTrailing: {
                if paused {
                    Text(formatSeconds(frozenSecs))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.orange)
                } else {
                    Text(origin, style: .timer)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.green)
                        .frame(minWidth: 40)
                }
            } minimal: {
                Image(systemName: paused ? "pause.fill" : "timer")
                    .foregroundStyle(paused ? .orange : .green)
            }
            .keylineTint(.indigo)
        }
    }
}

// MARK: - Lock screen / banner view

struct TimerBannerView: View {
    let attr: LiveActivitiesAppAttributes

    private var startMs: Double { sharedDefault.double(forKey: attr.prefixedKey("startTime")) }
    private var paused: Bool { sharedDefault.bool(forKey: attr.prefixedKey("paused")) }
    private var frozenSecs: Int { sharedDefault.integer(forKey: attr.prefixedKey("elapsedSeconds")) }

    private var origin: Date { Date(timeIntervalSince1970: startMs / 1000) }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: paused ? "pause.circle.fill" : "timer")
                .font(.system(size: 36))
                .foregroundStyle(paused ? .orange : .green)

            VStack(alignment: .leading, spacing: 4) {
                Text(paused ? "Paused" : "Running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if paused {
                    Text(formatSeconds(frozenSecs))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                } else {
                    Text(origin, style: .timer)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                }
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Helpers

private func formatSeconds(_ total: Int) -> String {
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%02d:%02d", m, s)
}

// MARK: - Simple emoji widget (original template — kept for reference)

struct IosLiveActivitiesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IosLiveActivitiesAttributes.self) { context in
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text("Leading") }
                DynamicIslandExpandedRegion(.trailing) { Text("Trailing") }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .keylineTint(Color.red)
        }
    }
}

// MARK: - Previews

extension IosLiveActivitiesAttributes {
    fileprivate static var preview: IosLiveActivitiesAttributes {
        IosLiveActivitiesAttributes(name: "World")
    }
}

extension IosLiveActivitiesAttributes.ContentState {
    fileprivate static var smiley: IosLiveActivitiesAttributes.ContentState {
        IosLiveActivitiesAttributes.ContentState(emoji: "😀")
    }
    fileprivate static var starEyes: IosLiveActivitiesAttributes.ContentState {
        IosLiveActivitiesAttributes.ContentState(emoji: "🤩")
    }
}

#Preview("Notification", as: .content, using: IosLiveActivitiesAttributes.preview) {
    IosLiveActivitiesLiveActivity()
} contentStates: {
    IosLiveActivitiesAttributes.ContentState.smiley
    IosLiveActivitiesAttributes.ContentState.starEyes
}
