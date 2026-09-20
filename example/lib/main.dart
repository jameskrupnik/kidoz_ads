import 'package:flutter/material.dart';
import 'package:kidoz_ads/kidoz_ads.dart';

/// Credentials come from Kidoz publisher onboarding and are passed in at
/// build time so this file can be committed without them:
///
/// ```
/// flutter run --dart-define=KIDOZ_PUBLISHER_ID=... \
///             --dart-define=KIDOZ_SECURITY_TOKEN=...
/// ```
///
/// **Kidoz has no test inventory** — no sample publisher id, no debug mode,
/// nothing equivalent to AdMob's test units. Every request this example makes
/// is a real one against a real account, so run it deliberately.
const publisherId = String.fromEnvironment('KIDOZ_PUBLISHER_ID');
const securityToken = String.fromEnvironment('KIDOZ_SECURITY_TOKEN');

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kidoz_ads',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Null until [KidozAds.initialize] has answered. Nothing may be requested
  /// before then — the SDK drops a request made against an uninitialised
  /// instance, and it arrives as a no-fill rather than as an error, which is
  /// an unpleasant thing to debug.
  bool? _started;

  String _log = 'Not initialised.';

  /// Whether the banner is in the tree at all.
  ///
  /// A Kidoz banner always occupies its declared size — it does not collapse
  /// itself on failure — so the host decides. This mirrors what a real app
  /// wants: the slot disappears rather than sitting empty.
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (publisherId.isEmpty || securityToken.isEmpty) {
      setState(() {
        _started = false;
        _log = 'No credentials. Pass --dart-define=KIDOZ_PUBLISHER_ID=... '
            'and --dart-define=KIDOZ_SECURITY_TOKEN=...';
      });
      return;
    }

    final started = await KidozAds.instance.initialize(
      publisherId: publisherId,
      securityToken: securityToken,
    );
    if (!mounted) return;
    setState(() {
      _started = started;
      _log = started ? 'SDK ready.' : 'SDK declined to start.';
    });
  }

  void _note(String message) {
    if (!mounted) return;
    setState(() => _log = message);
  }

  void _loadInterstitial() {
    _note('Loading interstitial…');
    KidozInterstitialAd.load(
      adLoadCallback: KidozFullScreenAdLoadCallback(
        onAdLoaded: (ad) {
          _note('Interstitial loaded.');
          // Single-use on both platforms: dispose on dismissal and load a
          // fresh one to show again.
          ad.fullScreenContentCallback = KidozFullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _note('Interstitial dismissed.');
              ad.dispose();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _note('Interstitial failed to show: ${error.code}');
              ad.dispose();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) =>
            _note('Interstitial ${error.code}: ${error.message}'),
      ),
    );
  }

  void _loadRewarded() {
    _note('Loading rewarded…');
    KidozRewardedAd.load(
      adLoadCallback: KidozFullScreenAdLoadCallback(
        onAdLoaded: (ad) {
          _note('Rewarded loaded.');
          ad.fullScreenContentCallback = KidozFullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
          );
          // The reward carries no name and no amount — Kidoz has no dashboard
          // field for either. It is the signal that the video was watched;
          // what it is worth is the app's business.
          ad.show(onUserEarnedReward: (ad) => _note('Reward earned.'));
        },
        onAdFailedToLoad: (error) =>
            _note('Rewarded ${error.code}: ${error.message}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _started ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('kidoz_ads')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_log),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: ready
                  ? () => setState(() => _showBanner = !_showBanner)
                  : null,
              child: Text(_showBanner ? 'Hide banner' : 'Show banner'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: ready ? _loadInterstitial : null,
              child: const Text('Interstitial'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: ready ? _loadRewarded : null,
              child: const Text('Rewarded'),
            ),
            const Spacer(),
            if (_showBanner)
              KidozBannerAd(
                listener: KidozBannerListener(
                  onAdLoaded: () => _note('Banner loaded.'),
                  onAdFailedToLoad: (error) {
                    _note('Banner ${error.code}: ${error.message}');
                    // There is no fill and no creative coming, so take the
                    // slot back rather than leaving a 320x50 hole.
                    setState(() => _showBanner = false);
                  },
                  // A Kidoz creative can close itself, which an AdMob banner
                  // never does. Nothing reloads after it, so treat it the
                  // same as a failure.
                  onAdClosed: () => setState(() => _showBanner = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
