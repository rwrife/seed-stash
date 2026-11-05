# Seed Stash plan

## Scope and architecture
Flutter stable single Dart codebase with windows/, android/, ios/ enabled by first issue. Local versioned packet records (ID, crop, variety, supplier, optional lot/pack date, location, count, photo path) and immutable dated count/germination events. Derived current count and tested/sprouted percentage; zero tested count means unknown. Local persistence first; no server or account. Export JSON with schema version and CSV inventory; validate and preview JSON before atomic restore. Optional photo files included in backup with path traversal protection.

## UX choice: A, platform-native adaptive
Shared screens with small AdaptiveScaffold/AdaptiveButton/AdaptiveDialog seam: Cupertino on iOS/iPadOS, Material 3 on Android, Fluent on Windows. Responsive phone list/detail to tablet/desktop two-pane navigation, not a blown-up phone UI. Honor platform back, file pickers, dialogs, scrolling and shortcuts. Golden/widget tests for TargetPlatform.iOS, TargetPlatform.android and TargetPlatform.windows at phone/tablet/desktop widths, screen-reader labels, scaling and keyboard navigation. Touch and mouse work without gestures only.

## Milestones / dependencies
1. Flutter skeleton and Windows/Android/iOS CI, pinned toolchain.
2. Domain model, immutable adjustments and local store.
3. Packet entry/search and count adjustments.
4. Germination samples and measured percentage, low-stock/old filters, shopping flags.
5. Adaptive platform UI/accessibility/golden tests.
6. JSON/CSV backup and restore, privacy review.
7. Icon and Windows release workflow; real Windows artifact on `v*` tag.

## Packaging
`com.infinityball.seedstash` for Android applicationId, iOS bundle ID and Windows/MSIX identity when used. App Store Connect registration blocked by `FORBIDDEN_ERROR.PLA_NOT_ACCEPTED`; owner accepts agreement before mobile signing. GitHub secrets are `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID`. `AppStore/description.txt` reviewed against implemented behavior; generate real `AppStore/icon.png` with spark-media OpenAI Images, wire Windows ico and Android/iOS launcher assets. `.github/workflows/release.yml`: `v*` or manual dispatch builds on `windows-latest` and attaches zipped portable build to GitHub release. Android debug build in Linux/Docker CI; iOS build on macOS runner as later milestone. TestFlight/Play submission later, not MVP. No fabricated build/CI claim.

## Risk / non-goals
Approximate packet counts and single germination samples cannot establish guaranteed viability; show provenance/date and unknown when absent. Handle duplicate varieties by packet ID and lot. Preserve user data on failed restore. No species identification, weather integration, diagnosis, automated purchasing or cloud sync. No native Swift-only app, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity or Flutter game engine. Icon and app binaries not yet present.
