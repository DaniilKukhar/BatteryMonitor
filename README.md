# TestTask — Battery Monitor

A test app that **reads the device battery level**, shows it on screen, and **periodically sends** the level to a server using `BGTaskScheduler` with an **audio-based keep-alive fallback** for better reliability.

## TL;DR
- **UI:** `BatteryViewController` shows battery level in the center.
- **Domain:** `BatteryService` exposes current level + Combine stream.
- **ViewModel:** `BatteryViewModel` formats text, schedules background refresh, triggers sends.
- **Networking:** `NetworkBatteryRepository` posts `{ "data": "<base64 json>" }`.
- **Fallback:** `SilentAudioKeepAlive` runs a silent `AVAudioEngine` + tolerant timer (skips in Low Power / very low battery).

## Requirements
- Xcode 15+ / iOS 15+.
- Enable **Background Modes**:
  - ✅ Background fetch (for `BGAppRefreshTask`)
  - ✅ Audio, AirPlay, and Picture in Picture (for silent engine fallback)
- **Info.plist** → `Permitted background task scheduler identifiers`:
  - `com.DaniilKukhar.TestTask.battery.refresh`

## How it works
1. `BatteryService` reads `UIDevice.batteryLevel` and publishes updates via Combine (`batteryLevelPublisher`).
2. `BatteryViewModel`:
   - Maps level → **UI text** (e.g., `"83%"`, `"--%"` when unknown) and exposes `batteryTextPublisher`.
   - Schedules `BGAppRefreshTask` and handles its execution (`handleBGTask`).
   - Sends the level via `BatteryRepository`.
3. `NetworkBatteryRepository`:
   - Wraps payload `{ level, timestamp }` → JSON → **base64** → `{ "data": "<b64>" }` and POSTs.
4. `BackgroundCoordinator` arms/disarms `SilentAudioKeepAlive` on app background/foreground.
5. `SilentAudioKeepAlive` keeps a **silent** audio engine running and fires a tolerant timer to call `sendOnceSilently()` (skips in Low Power mode and when not charging and ≤20%).

## UI
- `BatteryViewController` binds to `viewModel.batteryTextPublisher` and updates a centered `UILabel`.
- No direct `UIDevice` reads in the VC (logic lives in the service/view model).

## Configure / Run
1. Open the project in Xcode.
2. Ensure Background Modes + Info.plist identifier are set as above.
3. Build & run on a device (battery level is often **unknown on Simulator**).
4. Background the app; system may run the refresh later than the requested time.
5. The audio fallback keeps periodic sends more reliable, but is **auto-disabled in Low Power mode**.

## Known limitations
- `UIDevice.batteryLevel` can be **coarse** and update in steps; rounding may differ from system status bar.
- Background execution timing is **opportunistic**; iOS decides exact moments.
- The audio fallback still has a small power cost; we minimize it with **low sample rate**, **mono**, and **large IO buffer**.
