# Pocket Coach

Sideline iPhone app for calling Ultimate lines: even H1/H2 + C1/C2/C3 rotation, zone/kill interrupts, play time, wind-based D suggestions, and multi-game history on device.

Not App Store. Sideload from Xcode onto your phone.

## Open on a Mac

1. Copy this folder to the Mac (OneDrive is fine if it syncs).
2. Open `PocketCoach.xcodeproj` in Xcode 15+.
3. Select the **PocketCoach** scheme and your iPhone.
4. Signing & Capabilities → Team → your Apple ID.
5. Product → Run.

First launch uses a sample roster. Replace names on the Roster tab.

**Note:** This build changed the on-disk data shape. If an older build’s save fails to load, use Settings → Restore sample roster.

## Game tab

- **Game dropdown** (Game 1, Game 2, …). **New game** creates a new session and switches to it — never overwrites.
- Score with goal (game to N). Caps footer (half / soft / hard) is tournament-wide — tap to edit once.
- Wind chip → rules suggest **line + force**. Tap suggestion to load On now.
- **On now**: − to drop someone, Add/edit for one-off lines, tap name for injured/out.
- **Next lines**: equal cards for even / zone / custom. Drag to reorder, tap to put on field.
- Short pods after injury → accept fill suggestions (fill rotation), keep all 3 cutter pods.

## Roster tab

- Lineup dropdown at top (named lineups).
- **Edit pods** archives the previous setup into discreet History (clock icon).
- **Fill rotation** per pod — when someone is hurt, listed people rotate in.
- **Injured / sideline** instead of bench — tap to move.

## Defense tab

- Multiple clam lines (Clam 1/2/3) are fine; wind rules set force.
- **If we win the flip** preferences under wind rules.

## Time tab

- Filter: this game / today / all games.
- Players: least points first, injured at bottom, filter handlers/cutters. Tap a name to adjust ±1.
- Pods listed below players.

## Data

Local JSON on the phone. Games persist. Firebase sync is still optional/future (see join code in Settings).
