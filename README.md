# kidoz_ads

Direct Flutter bindings for the [Kidoz](https://www.kidoz.net/) advertising
SDK — the COPPA and GDPR-K certified contextual network for child-directed
apps. Banner, interstitial and rewarded ads on Android and iOS, with no
mediation layer.

Not affiliated with or endorsed by Kidoz.

## Why this exists

Kidoz ships native Android, iOS and Unity SDKs, plus official mediation
adapters for AdMob, AppLovin MAX and ironSource LevelPlay. There is no Flutter
plugin.

The adapters are the documented way to run Kidoz beside another network, and
every one of them routes the request through *that* network's SDK and *that*
network's account. That is useless if the reason you want Kidoz is to stop
depending on one — which is the reason this package was written. A Kidoz
adapter inside AdMob mediation is still an app whose ad revenue ends the day
the AdMob account does.

## Status

**The Dart layer is tested. The native layer has never been run.**

Worth stating plainly rather than discovering:

| Layer | State |
|---|---|
| Dart API, event routing, error mapping | 14 tests, green |
| Example app | Builds and runs; its widget test covers the no-credentials path |
| Android Kotlin | **Compiles** against `kidoz-android-native` 10.1.9 in a real app. Never *run* |
| iOS Swift | **Compiles, links and archives** against `KidozSDK` 10.1.5 — it is inside a submitted App Store build. Never *run* |
| Any ad actually serving | **Unverified** |

Both halves now compile inside a consuming Flutter app, which is what caught
the two faults listed below — `KidozError` is non-null in every Android
callback, and `consumer-rules.pro` has to exist. Neither was visible in the
published docs.

What compiling cannot tell you is whether an ad arrives. That needs live
requests against a real publisher account, and **Kidoz has no test inventory
to request against** — no sample app id, no debug mode, nothing equivalent to
AdMob's test units. Every verification impression is a real one. Plan for that
rather than discovering it.

Credentials come only through
[publisher onboarding](https://accounts.kidoz.net/publishers/register). The
sample credentials in Kidoz's own repo are marked *"be sure not to publish your
app with them"* and are not a substitute.

Two things are most likely to need correcting on first device run, and both are
commented at the site:

- **`setLayoutWithoutShowing()` on Android.** Kidoz's programmatic banner
  attaches itself to the *activity window*, which in a Flutter app means it
  floats over the whole `FlutterView` ignoring the slot the widget tree
  reserved. The XML path — `setLayoutWithoutShowing()`, `load()`, then `show()`
  once ready — is what keeps it inside the platform view. This is the single
  most load-bearing call in the Android source.
- **Banner sizes.** Kidoz publishes no size API and no size table. `320×50` is
  the default here because it is the only size Kidoz's own iOS sample
  demonstrates. `leaderboard` and `mediumRectangle` are offered because the
  underlying view takes whatever frame it is given, but **neither is confirmed
  to fill.** A banner that reports `loaded` and renders blank is a size
  mismatch until proven otherwise.

## Install

```console
$ flutter pub add kidoz_ads
```

or, in `pubspec.yaml`:

```yaml
dependencies:
  kidoz_ads: ^0.1.0
```

Requires Flutter 3.24 and Dart 3.6. Android `minSdk` 21, iOS 13.

Android pulls `net.kidoz.sdk:kidoz-android-native:10.1.9` from Maven Central;
iOS pulls `KidozSDK` 10.1.5 from CocoaPods. Both are pinned exactly, for the
same reason `google_mobile_ads` is pinned in the apps that consume this: an ad
SDK minor release is a change to a native dependency graph, and the way it
breaks is at one platform's link step only.

iOS also needs Kidoz's SKAdNetwork id in `Info.plist`:

```xml
<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>v79kvwwj4g.skadnetwork</string>
  </dict>
</array>
```

### CocoaPods only, and not by choice

Every build prints *"kidoz_ads does not have Swift Package Manager support"*,
which will become an error in a future Flutter. It is not an oversight and it
cannot be fixed here: a plugin can only offer SPM if its native dependency
does, and **Kidoz distributes `KidozSDK` through CocoaPods and Maven only** —
there is no `Package.swift` in their SDK repo and no Swift package to depend
on. Use CocoaPods for the iOS half until Kidoz publishes one.

## Example

[`example/`](example) is a small app with a button per format. It needs real
credentials, passed at build time so the file stays committable:

```console
$ cd example
$ flutter run --dart-define=KIDOZ_PUBLISHER_ID=... \
              --dart-define=KIDOZ_SECURITY_TOKEN=...
```

Without them it still builds and runs, and says what is missing rather than
throwing — which is also the path its widget test covers.

## Use

```dart
await KidozAds.instance.initialize(
  publisherId: '...',
  securityToken: '...',
);

// Banner — always occupies its size; collapse it yourself on failure.
KidozBannerAd(
  listener: KidozBannerListener(
    onAdFailedToLoad: (error) => collapseTheSlot(),
    onAdClosed: collapseTheSlot,
  ),
)

// Interstitial
KidozInterstitialAd.load(
  adLoadCallback: KidozFullScreenAdLoadCallback(
    onAdLoaded: (ad) => ad.show(),
    onAdFailedToLoad: (error) => fallBackToAnotherNetwork(error),
  ),
);
```

### There is no placement id, anywhere

Kidoz keys everything off the publisher credentials and picks the creative
contextually. If you are porting from AdMob or InMobi, the placement argument
you are looking for does not exist, and a test in this package asserts one
never reappears in the payload by copy-paste.

### There is no consent API, and that is the design — but read the next part

Every other network in this family needs a privacy signal pushed into it —
InMobi takes a GDPR consent dictionary, AdMob needs `childDirected` and a
`maxAdContentRating` set *before* `initialize()`, Unity needs three consent
flags. Kidoz needs none, because contextual-only is the product: the SDKs are
verified to carry **no advertising identifier at all**, so there is no
identifier to withhold and no personalisation to turn off.

**The absence of `setChildDirected` here is not a missing feature.** The
network has no other mode.

### …and in the EEA that absence is your problem to solve

The sentence above is true about *personalisation* and it is easy to finish
reading one clause too early. It also means there is **no way to tell the SDK
that a user did not consent** — so if you are serving in the EEA, the UK or
Switzerland, the only lever you have is whether `initialize` is called at all.

Two things make that matter, and they are not obvious from the SDK:

- **Kidoz collects a truncated IP address.** No advertising identifier, but a
  truncated IP is still personal data under GDPR, and both stores classify it
  as coarse/approximate **location** on their privacy forms. Kidoz's own Data
  Safety guidance has you declare it as collected *and shared*.
- **A CMP does not cover it.** If you gather consent through Google's UMP, that
  consent covers Google and the ad partners named in your AdMob message. Kidoz
  is a direct SDK on its own publisher account — that is the entire point of
  this package — so it is in no such list and nothing your user agreed to
  reaches it.

The shape that works is to gate initialization on the answer, and to make the
gate **fail closed**: assume a consent regime applies until you positively
learn otherwise, because a wrong "no" is a request you had no basis to make.

```dart
// `regimeApplies` defaults to true and is only lowered on a positive
// "consent not required" from your CMP. Awaited, not read — asking before
// the CMP has answered must not come back as "no regime here".
if (await consent.regimeApplies()) return; // leave the slot to another network

await KidozAds.instance.initialize(
  publisherId: '...',
  securityToken: '...',
);
```

None of this is legal advice, and a package cannot know your jurisdiction, your
CMP or what your privacy policy says. It is here because the "no consent API"
line above reads as "nothing to do", and for one of us it did — the app this
package was written for shipped that reading and had to correct it.

### The reward carries no payload

`onRewardReceived(ad)` on both platforms — no name, no amount, because Kidoz
has no dashboard field to configure one. The reward is the *signal that the
video was watched*; what it is worth is entirely the app's business. Code
ported from AdMob or InMobi will compile against a reward object that does not
exist here.

## Policy notes

These are the findings that shaped the package. Re-read the primary sources
before acting on any of them — **policies change and a repo cannot tell you a
network's current terms.**

### Running a fallback network behind Kidoz

Worth checking rather than assuming, because some networks prohibit exactly
this — AppLovin's publisher terms forbid mediating MAX inside internal or
third-party mediation, with account suspension as the stated remedy. Running
your own waterfall is not automatically safe.

Checked 2026-09-18:

**Kidoz has no equivalent clause.** Their public Terms of Service carry one
compliance line — *"Maintain compliance with all applicable laws including
COPPA and GDPR-K"* — and nothing on exclusivity, waterfall position, minimum
volume, or competing SDKs. (`kidoz.net/sdk-terms-and-conditions/` 404s.)

Absence of a clause is weak evidence on its own. What makes it safe is the
positive evidence:

- Kidoz **publishes official mediation adapters for AdMob, AppLovin MAX and
  ironSource LevelPlay.** A network that ships an AdMob adapter cannot
  coherently forbid you running AdMob.
- Kidoz is a **Prebid header-bidding adapter**, i.e. built to compete in an
  auction against other demand.
- The SDK documents S2S/ORTB bidding, which is inherently multi-demand.

### What the Publisher Agreement actually says

Read 2026-09-18, and worth reading yourself rather than trusting secondhand
summaries — including this one. Two clauses matter:

- **Non-exclusive, in terms.** *"This Agreement is non-exclusive. Neither Party
  is required to purchase, sell or make available any minimum amount of
  inventory, traffic, Ads or services"* (§2). That settles the fallback
  question above contractually rather than by inference.
- **No publisher COPPA representation.** The agreement describes *Kidoz's* own
  COPPA/GDPR-K compliance and imposes no equivalent warranty on the publisher,
  beyond generic obligations to hold the necessary rights (§4) and provide the
  necessary notices and consents (§10).

That last point corrects a claim repeated in third-party documentation — that
Kidoz publishers must confirm *all* of their content properties are COPPA
compliant and track no U13 users. That sentence appears in integration docs
elsewhere, **not** in the agreement you actually sign. If your portfolio mixes
child-directed and adult apps, check the current agreement text before assuming
either reading.

Also in §8: Kidoz may defer payment until the balance reaches **US$150**, with
reporting 30 days after month-end. On a contextual kids-only network that
threshold can take a while, so plan for a long first gap.

### On rewarded video for this audience

The format is available and this package wraps it. That is not an argument for
using it. A reward a nine-year-old can only obtain by watching an ad turns
declining into losing something, and both stores restrict incentivised ads
harder as the target age falls. Check the app's age rating and the store's
families policy before wiring the rewarded path to anything a player wants.

## Licence

MIT. See [LICENSE](LICENSE).
