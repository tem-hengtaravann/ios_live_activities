//
//  IosLiveActivitiesControl.swift
//  IosLiveActivities
//
//  Created by lms-taravann on 27/5/26.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct IosLiveActivitiesControl: ControlWidget {
    static let kind: String = "com.example.iosLiveActivities.IosLiveActivities"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Start Timer",
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(isRunning ? "On" : "Off", systemImage: "timer")
            }
        }
        .displayName("Timer")
        .description("A an example control that runs a timer.")
    }
}

extension IosLiveActivitiesControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            IosLiveActivitiesControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            let isRunning = !Activity<LiveActivitiesAppAttributes>.activities.isEmpty
            return IosLiveActivitiesControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Timer Name Configuration"

    @Parameter(title: "Timer Name", default: "Timer")
    var timerName: String
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"

    @Parameter(title: "Timer Name")
    var name: String

    @Parameter(title: "Timer is running")
    var value: Bool

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        if value {
            // Start a fresh live activity from the control widget.
            let attrs = LiveActivitiesAppAttributes()
            let startMs = Date().timeIntervalSince1970 * 1000
            sharedDefault.set(startMs, forKey: attrs.prefixedKey("startTime"))
            sharedDefault.set(false,   forKey: attrs.prefixedKey("paused"))
            sharedDefault.set(0,       forKey: attrs.prefixedKey("elapsedSeconds"))
            let content = ActivityContent(
                state: LiveActivitiesAppAttributes.ContentState(),
                staleDate: nil
            )
            _ = try? Activity<LiveActivitiesAppAttributes>.request(
                attributes: attrs,
                content: content
            )
        } else {
            for activity in Activity<LiveActivitiesAppAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        return .result()
    }
}
