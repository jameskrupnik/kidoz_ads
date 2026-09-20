# Changelog

## 0.1.0

Initial cut. Banner, interstitial and rewarded ads over the Kidoz native SDKs
with no mediation layer.

- Android against `net.kidoz.sdk:kidoz-android-native:10.1.9`, iOS against
  `KidozSDK` 10.1.5, both pinned exactly.
- One method channel, with ads keyed on an id minted in Dart — Kidoz's load
  entry points are static and hand the ad to a callback, so there is no object
  to key on until after the load fires.
- Error codes are this package's own (`NO_FILL`, `SHOW_FAILED`,
  `NOT_INITIALIZED`, `INTERNAL_ERROR`) and assigned from *which callback
  fired*. `KidozError` carries a message and no status enum, so the
  distinction a chain needs does not exist in the SDK to pass through.
- Full-screen callback names follow `google_mobile_ads` and `inmobi_ads`
  rather than Kidoz's own, so an app running several networks behind one
  interface reads the same for every leg.

- An example app with a button per format, which reports missing credentials
  rather than throwing so it opens on a machine with no Kidoz account.
- A README section on consent in the EEA. The SDK's lack of a consent API is
  correct for personalisation and is not the end of the matter: Kidoz collects
  a truncated IP, a CMP's consent does not reach a direct SDK, and the only
  lever left is whether `initialize` is called.

**Both native halves compile inside a consuming app and the iOS half is
inside a submitted App Store build, but neither has been observed serving an
ad.** That needs publisher credentials, which come from Kidoz onboarding, and
Kidoz has no test inventory — every verification impression is a real one. See
the Status table in the README for the two things most likely to need
correcting on first device run.

No Swift Package Manager support, and it cannot be added here: `KidozSDK` is
distributed through CocoaPods and Maven only.
