# Changelog

## 0.1.0

Initial cut. Banner, interstitial and rewarded ads over the Kidoz native SDKs
with no mediation layer.

- Android against `net.kidoz.sdk:kidoz-android-native:10.1.9`, iOS against
  `KidozSDK` 10.1.5, both pinned exactly.
- One method channel, with ads keyed on an id minted in Dart — Kidoz's load
  entry points are static and hand the ad to a callback, so there is no object
  to key on until after the load fires.
- Error codes are this package's own `KidozAdErrorCode` enum (`noFill`,
  `showFailed`, `notInitialized`, `internalError`) and assigned from *which
  callback fired*. `KidozError` carries a message and no status enum, so the
  distinction a chain needs does not exist in the SDK to pass through.
- `fullScreenContentCallback` is declared on each ad type with that type, so
  a rewarded ad's callbacks receive a `KidozRewardedAd`, not the base class.
- Full-screen callback names follow `google_mobile_ads` and `inmobi_ads`
  rather than Kidoz's own, so an app running several networks behind one
  interface reads the same for every leg.

- An example app with a button per format, which reports missing credentials
  rather than throwing so it opens on a machine with no Kidoz account.
- A README section on consent in the EEA. The SDK's lack of a consent API is
  correct for personalisation and is not the end of the matter: Kidoz collects
  a truncated IP, a CMP's consent does not reach a direct SDK, and the only
  lever left is whether `initialize` is called.

- Interstitial and rewarded calls that the native side refuses (for
  example Android's `NO_ACTIVITY` when the engine has no activity) now reach
  `onAdFailedToLoad` / `onAdFailedToShowFullScreenContent` with
  `internalError`. Before this they escaped as uncaught async errors and no
  callback ran. `dispose()` no longer throws.
- iOS banners are now freed when their widget goes away. `KidozBannerView`
  holds its delegate strongly, and the platform view was its own delegate, so
  neither was ever released and `close()` never ran.

iOS builds with Swift Package Manager or CocoaPods. Both pin `KidozSDK`
10.1.5, from Kidoz's own Swift package or its pod, and both resolve to the
same binary.
