# Seed Stash

Offline seed-packet library for home growers: track varieties, packet counts, germination checks, and next-season shopping across phone, tablet, and Windows.

## Why / who
Seed packets disappear into drawers; remaining counts and old germination results get lost. Home growers can record purchased packets, adjust approximate seed counts, log dated germination checks, and build a shopping list before ordering. This is a packet inventory, not a garden-bed timeline (`bed-ledger`) or plant-care diagnosis.

## Workflow and MVP
1. Add a packet: crop, variety, supplier, lot/pack date if known, approximate remaining seeds, optional photo and storage location.
2. Record sowing/consumption as a count adjustment; keep dated audit history.
3. Log a germination sample (tested and sprouted counts) with date; show measured rate, not predicted viability.
4. Filter low-stock and old packets; manually flag packets for next-season shopping. Export JSON backup and CSV inventory.

No plant identification, climate prediction, purchase links, account, cloud sync, pesticide guidance, or automatic viability guarantees. Counts are user estimates; germination sample does not prove full-packet quality.

## Platforms and data
Flutter stable, Dart; Windows, Android phones/tablets, iOS/iPadOS. Windows desktop build primary. Native-feeling adaptive widgets: Cupertino on iOS, Material 3 on Android, Fluent on Windows, with shared screens and responsive navigation. Touch, mouse, full keyboard navigation, screen reader labels, scalable text and high contrast required. Local app storage only; optional photo permission when selecting image, file access only for user-selected import/export; no network permission required for core workflow. Backups are user-owned; restore previews before replacing data. No health or medical claims.

Identifier: `com.infinityball.seedstash` for Android and iOS, and Windows package identity if used. ASC registration **not completed**. Manual setup required: `com.infinityball.seedstash` could not be registered: `FAILED bundleId lookup rejected: FORBIDDEN_ERROR.PLA_NOT_ACCEPTED`. Account owner must accept Apple Program License Agreement before retrying.

## Status and milestones
Flutter 3.47.7 project skeleton and platform build CI exist. Packet inventory, app icon, and release workflow remain future milestones. Generated Flutter template launcher icons are not product artwork; real `AppStore/icon.png` must be generated through spark-media OpenAI Images and wired to all three platforms. `AppStore/description.txt` remains draft listing copy. See [PLAN.md](PLAN.md) and issues.

## Develop
Once skeleton issue lands: use pinned Flutter stable version in `toolchain.json`; `flutter create --platforms=windows,android,ios .`, then `flutter test`, `flutter build windows --release`, `flutter build apk --debug`. Linux host builds use Docker; Windows build runs on `windows-latest`. Release workflow `.github/workflows/release.yml` on `v*` tag or manual dispatch zips Windows build into GitHub release. TestFlight and Play publish later, with secret names `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` (no values in source).
