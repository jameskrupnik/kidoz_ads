import 'package:flutter/material.dart';
import 'package:kidoz_ads/kidoz_ads.dart';

part 'home_page.dart';

/// Credentials come from Kidoz publisher onboarding and are passed in at
/// build time so this file can be committed without them:
///
/// ```sh
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
