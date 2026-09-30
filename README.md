# Yutori

A native SwiftUI study app built for the Shipaton demo. Study sessions grow collectible bowls, with course tracking, weekly stats, streaks, Live Activities and app icon customization.

## Run the demo

1. Install Xcode with the iOS 26.5 SDK and simulator runtime (the app deployment target is iOS 26.5).
2. Open `Yutori.xcodeproj` and let Swift Package Manager resolve RevenueCat.
3. Select the **Yutori** scheme, an iOS 26.5 simulator, and the **Debug** configuration.
4. Configure RevenueCat as described below, then Run. For a physical device, select your own signing team for both app and activity extension.

## RevenueCat Test Store

This submission uses RevenueCat **Test Store**. Simulated purchases do not charge money. The local `Yutori/RevenueCatSecrets.plist` is intentionally ignored by Git and is not included in a clone.

In **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**, add `REVENUECAT_API_KEY` with the public SDK key for your RevenueCat Test Store. If a local secrets plist exists, its key takes precedence over the environment variable.

The RevenueCat project must have:

- Active entitlement: `studybite_pro`.
- A current offering (or an offering named `default`).
- Monthly and annual packages attached to that offering and to the entitlement. The fallback product identifiers are `monthly` and `yearly`.

The demo deliberately configures Test Store only in Debug. Release compiles, but purchases are not configured. App Store/TestFlight publication requires a separate Apple RevenueCat app and production configuration; this repository is being submitted as an Xcode demo.

## Domain regression checks

Run `bash QA/run-domain-checks.sh` with Xcode selected, or set `DEVELOPER_DIR` to your Xcode `Contents/Developer` directory.

The script compiles the current domain sources unchanged, using isolated UserDefaults. Only localization and the purchase entitlement service are substituted for this standalone macOS test runner. It checks courses, timer persistence, level boundaries, manual unlocks, collection, time edits, session deletion, starter gifts, resets, streaks and corrupt-data protection. It does not replace simulator/device testing or test RevenueCat itself.
