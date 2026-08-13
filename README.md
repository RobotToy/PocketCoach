# Pocket Coach

Sideline iPhone app for calling Ultimate lines: even H1/H2 + C1/C2/C3 rotation, zone/kill interrupts, play time, and wind-based D suggestions.

Not App Store. Sideload from Xcode onto your phone.

## Open on a Mac

1. Copy this folder to the Mac (OneDrive is fine if it syncs).
2. Open `PocketCoach.xcodeproj` in Xcode 15+.
3. Select the **PocketCoach** scheme and your iPhone.
4. Signing & Capabilities → Team → your Apple ID (free account works ~7 days per build).
5. Product → Run.

First launch uses a **sample roster** (Weekend lineup, dummy D lines). Replace names on the Roster tab.

## How to call a game

- **Game** tab is the sideline screen. Default line is next handler pod + next cutter pod (3+4).
- **We scored / They scored** increments play time. Even rotation advances H and C pointers. Zone/kill buttons do **not** skip the next even pods.
- Tap the wind chip to set no wind / crosswind / upwind-downwind. Suggested D appears; tap it to load that saved 7.
- **Roster** tab: one team roster, multiple named **lineups** (duplicate for semis / injury backup). Injury is global; pod moves only change the active lineup.
- **Defense** tab: saved clam/cup/kill 7s + editable wind rules.
- **Time** tab: weekend vs game points and the 80/20 meter.

## Data

Local JSON in the app’s Application Support folder. Survives relaunch on that phone. Team settings include a **join code** for a future multi-phone sync.

### Optional Firebase (not wired yet)

v1 is local-only so it works with no signal. To add sync later:

1. Create a Firebase project → add an iOS app with bundle id `com.pocketcoach.app`.
2. Download `GoogleService-Info.plist` into the `PocketCoach/` source folder (it is gitignored).
3. Add the Firebase iOS SDK (Auth + Firestore) via Swift Package Manager.
4. Enable Firestore offline persistence and anonymous auth.
5. Store the `Team` document at `teams/{joinCode}`. Last write wins is fine for 2–3 phones on the sideline.

## Notes

- Portrait iPhone, iOS 17+.
- Add a 1024×1024 App Icon in Assets if Xcode warns.
- “Restore sample roster” in Game → gear resets dummy data.
