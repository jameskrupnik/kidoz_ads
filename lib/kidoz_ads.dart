/// Direct Flutter bindings for the Kidoz advertising SDK.
///
/// Kidoz ships native Android, iOS and Unity SDKs, plus mediation adapters for
/// AdMob, AppLovin MAX and ironSource LevelPlay — but no Flutter plugin. The
/// adapters are the documented way to run Kidoz beside another network, and
/// they all route the request through *that* network's SDK and account, which
/// is useless if the reason you want Kidoz is to not depend on one.
///
/// This package is the other thing: a direct wrapper over
/// `net.kidoz.sdk:kidoz-android-native` and `KidozSDK` on iOS, with no
/// mediator in the path.
///
/// ```dart
/// await KidozAds.instance.initialize(
///   publisherId: '...',
///   securityToken: '...',
/// );
///
/// KidozInterstitialAd.load(
///   adLoadCallback: KidozFullScreenAdLoadCallback(
///     onAdLoaded: (ad) => ad.show(),
///     onAdFailedToLoad: (error) => fallBackToAnotherNetwork(error),
///   ),
/// );
/// ```
///
/// ### What makes this network different from the others
///
/// Kidoz is COPPA and GDPR-K certified and contextual only. Its SDKs are
/// verified to contain **no advertising identifier** — no IDFA on iOS, no
/// `AD_ID` on Android — which is why there is no consent API in this package
/// and no child-directed flag to set. See `KidozAds` for why that absence is
/// the design rather than a gap. (Backticks, not a doc link: a library-level
/// comment resolves against this file's imports, and this file only exports.)
///
/// Two things follow that are worth knowing before you integrate:
///
///  - **Registering a publisher account is a representation about your whole
///    portfolio.** Kidoz requires publishers to confirm that *all* of their
///    content properties are COPPA and GDPR compliant and perform no tracking
///    of under-13 users. That is account-scoped language, so an app that does
///    track cannot simply be left off the Kidoz account and forgotten about.
///  - **There is no placement id anywhere in this API.** Kidoz keys everything
///    off the publisher credentials and picks the creative contextually. If you
///    are porting from AdMob or InMobi, the placement argument you are looking
///    for does not exist.
///
/// Not affiliated with or endorsed by Kidoz.
library;

export 'src/kidoz_ad_error.dart' show KidozAdError;
export 'src/kidoz_ads_base.dart' show KidozAds;
export 'src/kidoz_banner_ad.dart'
    show KidozBannerAd, KidozBannerListener, KidozBannerSize;
export 'src/kidoz_full_screen_ad.dart'
    show
        KidozFullScreenAd,
        KidozFullScreenAdLoadCallback,
        KidozFullScreenContentCallback,
        KidozInterstitialAd,
        KidozOnUserEarnedReward,
        KidozRewardedAd;
