# ios_live_activities

## Live Activities Implementation — Assessment & Explanation

---

### Architecture at a Glance

```
Flutter App (Runner process)
      │
      │  Method Channel (live_activities plugin)
      ▼
  Swift / ActivityKit  ──writes──▶  App Group UserDefaults
                                          │
                                          │  read at render time
                                          ▼
                              Widget Extension process
                              (TimerLiveActivityWidget)
                                    │          │
                             Lock Screen     Dynamic Island
                              banner           compact / expanded / minimal
```

Two separate OS processes are involved. They cannot share memory directly, so all dynamic data flows through a shared **App Group UserDefaults** container (`group.iosLiveActivities`).

---

### Files

| File | Process | Role |
|---|---|---|
| `lib/main.dart` | Flutter / Runner | UI, timer logic, plugin calls |
| `IosLiveActivitiesLiveActivity.swift` | Widget Extension | Live Activity UI (lock screen + Dynamic Island) |
| `IosLiveActivitiesControl.swift` | Widget Extension | Control Widget (iOS 18 Control Center toggle) |
| `IosLiveActivitiesBundle.swift` | Widget Extension | Entry point that registers all widgets |

---

### How It Works — Step by Step

#### 1. Plugin Initialisation (`lib/main.dart:66–71`)

```dart
await _plugin.init(
  appGroupId: 'group.iosLiveActivities',
  urlScheme: 'ila',
);
```

The `live_activities` plugin bridges to native Swift via a Flutter Method Channel. `init` tells the native side which App Group to write UserDefaults into, and which URL scheme the app responds to (for tapping the Live Activity to deep-link back).

---

#### 2. Starting the Timer (`_start`, `main.dart:83–110`)

**Flutter side:**
- Calculates `origin` — a `DateTime` shifted back by any already-elapsed time so the running elapsed formula is always `now − origin`.
- Starts a 1-second `Timer.periodic` to update the in-app display.
- Calls `_plugin.createActivity('timer', data)` with:
  - `startTime` — epoch milliseconds (as a `double`).
  - `paused: false`.

**Native side (plugin internals, not in this repo):**
- Calls `Activity<LiveActivitiesAppAttributes>.request(...)` to register the Live Activity with ActivityKit.
- Writes `startTime` and `paused` into the shared UserDefaults under a UUID-prefixed key (e.g. `<uuid>_startTime`).
- Returns the system-assigned activity UUID back to Dart as `_activityId`.

---

#### 3. Rendering the Live Activity (`IosLiveActivitiesLiveActivity.swift`)

The widget extension process wakes whenever ActivityKit signals a content update. It reads state **directly from UserDefaults** (not from the `ContentState` struct, which is intentionally empty):

```swift
let paused  = sharedDefault.bool(forKey: attr.prefixedKey("paused"))
let startMs = sharedDefault.double(forKey: attr.prefixedKey("startTime"))
let origin  = Date(timeIntervalSince1970: startMs / 1000)
let frozenSecs = sharedDefault.integer(forKey: attr.prefixedKey("elapsedSeconds"))
```

**Why `ContentState` is empty:** The `live_activities` plugin passes all data through UserDefaults rather than encoding it in the `ActivityContent`. This avoids the 4 KB ActivityKit push payload limit and lets the widget read data without waiting for a push update.

**Running state:** SwiftUI's `Text(origin, style: .timer)` is used — this is a system-driven auto-counting timer that ticks every second without any app code running. The origin date acts as an anchor and the OS handles the counting.

**Paused state:** The auto-timer cannot be "frozen", so the widget switches to `Text(formatSeconds(frozenSecs))` — a static string of the elapsed seconds captured at pause time.

---

#### 4. Dynamic Island Regions

| Region | Running | Paused |
|---|---|---|
| **Compact leading** | `timer` SF Symbol (green) | `pause.fill` SF Symbol (orange) |
| **Compact trailing** | Auto-counting timer text | Static frozen time text |
| **Expanded center** | Large auto-counting timer | Large static frozen time |
| **Expanded bottom** | "Running" label | "Paused" label |
| **Minimal** | `timer` icon | `pause.fill` icon |

---

#### 5. Pausing (`_stop`, `main.dart:112–127`)

```dart
await _plugin.updateActivity(_activityId!, {
  'startTime': _origin?.millisecondsSinceEpoch.toDouble() ?? 0.0,
  'paused': true,
  'elapsedSeconds': _elapsed.inSeconds,   // ← snapshot for display
});
```

The plugin writes the new values to UserDefaults and calls `activity.update(...)` to wake the widget extension. The widget then sees `paused == true` and switches to the static `frozenSecs` display.

---

#### 6. Resuming (`_start` when `isResume`, `main.dart:102–108`)

```dart
if (isResume && _activityId != null) {
  await _plugin.updateActivity(_activityId!, data);
}
```

`_origin` has already been shifted back by `_elapsed` (line 87), so the new `startTime` written to UserDefaults correctly represents the adjusted anchor. The widget transitions back to the auto-counting `Text(..., style: .timer)`.

---

#### 7. Reset / End (`_reset`, `main.dart:129–145`)

```dart
await _plugin.endActivity(_activityId!);
```

ActivityKit removes the Live Activity from the lock screen and Dynamic Island. `_activityId` is cleared in Dart.

---

#### 8. Background Drift Correction (`didChangeAppLifecycleState`, `main.dart:56–63`)

The in-app 1-second ticker is suspended while the app is in the background. When the app returns to the foreground:

```dart
if (state == AppLifecycleState.resumed && _status == _Status.running) {
  setState(() => _elapsed = DateTime.now().difference(_origin!));
}
```

This re-anchors the displayed elapsed time from the absolute `_origin` rather than trusting the potentially-drifted ticker count.

---

#### 9. Control Widget (`IosLiveActivitiesControl.swift`)

An iOS 18 **Control Widget** (accessible from Control Center and the lock screen long-press controls) that independently starts and stops the Live Activity without opening the app. When toggled on, it creates a new `LiveActivitiesAppAttributes` activity and writes its own UserDefaults keys. When toggled off, it ends all active activities.

---

### Key Design Decisions

| Decision | Why |
|---|---|
| Empty `ContentState` | All data passes through UserDefaults to avoid the ActivityKit payload size limit and enable the widget to self-serve data without push updates. |
| `Text(origin, style: .timer)` | The OS drives the counter natively — no timer code runs in the extension process. |
| `elapsedSeconds` snapshot on pause | `Text(.timer)` cannot be paused mid-count; switching to a static string is the only correct approach. |
| Origin-shift on resume | Keeps the single `startTime` value self-consistent regardless of how many pause/resume cycles occurred. |
| UUID-prefixed UserDefaults keys | Supports multiple concurrent Live Activities without key collisions. |

---

### Data Flow Summary

```
User taps Start
  └─► Flutter shifts _origin, starts ticker
  └─► plugin.createActivity → UserDefaults[uuid_startTime, uuid_paused=false]
                            → ActivityKit.request(...)
                            ← returns activityId

ActivityKit wakes Widget Extension
  └─► reads UserDefaults[uuid_startTime] → origin date
  └─► Text(origin, style: .timer) — OS counts up automatically

User taps Stop
  └─► Flutter cancels ticker, snapshots _elapsed.inSeconds
  └─► plugin.updateActivity → UserDefaults[uuid_paused=true, uuid_elapsedSeconds=N]
                            → ActivityKit.update(...)

ActivityKit wakes Widget Extension
  └─► reads paused=true → Text(formatSeconds(N)) — static display

User taps Reset
  └─► plugin.endActivity → ActivityKit.end(...)
  └─► Live Activity dismissed from lock screen / Dynamic Island
```
