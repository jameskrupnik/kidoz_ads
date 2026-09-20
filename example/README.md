# kidoz_ads example

One button per format — banner, interstitial, rewarded — over the real Kidoz
SDKs.

## Running it

Credentials come from Kidoz [publisher
onboarding](https://accounts.kidoz.net/publishers/register) and are passed at
build time, so this directory stays committable:

```console
$ flutter run --dart-define=KIDOZ_PUBLISHER_ID=... \
              --dart-define=KIDOZ_SECURITY_TOKEN=...
```

Without them the app still builds and runs, reports what is missing and leaves
every button disabled. That is deliberate: a plugin example that throws on a
machine with no account is one nobody can open, and it is the path the widget
test covers.

## Every request here is a real one

**Kidoz has no test inventory** — no sample publisher id, no debug mode,
nothing equivalent to AdMob's test units. The sample credentials in Kidoz's own
repo are marked *"be sure not to publish your app with them"* and are not a
test pair. So each tap books a real request against a real account. Run it
deliberately, and do not leave it looping.

## What it demonstrates that the README only describes

- **The host collapses the banner slot, not the widget.** A Kidoz banner always
  occupies its declared size; `onAdFailedToLoad` and `onAdClosed` are both
  signals to take the space back, and this app removes the widget on either.
- **`onAdClosed` on a banner.** A Kidoz creative can close itself, which an
  AdMob banner never does. Nothing reloads behind it.
- **Full-screen ads are single-use.** Dispose on dismissal and load a fresh one
  to show again.
- **The reward carries no payload** — no name, no amount. It is the signal that
  the video was watched.
