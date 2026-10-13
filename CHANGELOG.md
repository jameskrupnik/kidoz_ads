# Changelog

## 0.1.0

First release.

- Kidoz SDK on Android (`net.kidoz.sdk:kidoz-android-native:10.1.9`) and iOS
  (`KidozSDK` 10.1.5), pinned exactly on Gradle, CocoaPods and Swift Package
  Manager, with no mediation layer
- `KidozAds.initialize` with the publisher id and security token; no
  placement ids anywhere
- `KidozRewardedAd`: load, show, and a reward callback that fires before
  dismissal and survives a double-tapped show
- `KidozInterstitialAd`: load, show
- `KidozBannerAd`: a widget, hybrid composition on Android, following the
  ambient text direction, with `onAdClosed` for creatives that close
  themselves
- `fullScreenContentCallback` typed to the ad's own class, so handlers get a
  `KidozRewardedAd` or `KidozInterstitialAd` without a cast, and callback
  names that match `google_mobile_ads` and `inmobi_ads`
- `KidozAdError` with this package's `KidozAdErrorCode` (`noFill`,
  `showFailed`, `notInitialized`, `internalError`), the same on both
  platforms, plus Kidoz's own number as `nativeCode` for logs
- Loads before initialization, refused loads and refused shows arrive through
  the callbacks rather than as unhandled exceptions or silence
- R8 keep rules ship in `consumer-rules.pro`
- A runnable example app that reports missing credentials instead of throwing
- README notes on consent in the EEA, the Publisher Agreement, and rewarded
  video for a child audience
