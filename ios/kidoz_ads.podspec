Pod::Spec.new do |s|
  s.name             = 'kidoz_ads'
  s.version          = '0.1.0'
  s.summary          = 'Direct Flutter integration for the Kidoz advertising SDK.'
  s.description      = <<-DESC
Banner, interstitial and rewarded ads from Kidoz — the COPPA and GDPR-K
certified contextual network for child-directed apps — on Android and iOS,
integrated directly against the native SDKs with no mediation layer.
                       DESC
  s.homepage         = 'https://github.com/jameskrupnik/kidoz_ads'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'James Krupnik' => 'jameskrupnik@gmail.com' }
  s.source           = { :path => '.' }
  # Shared with Swift Package Manager; see kidoz_ads/Package.swift.
  s.source_files     = 'kidoz_ads/Sources/kidoz_ads/**/*.swift'

  s.dependency 'Flutter'
  # 10.1.5, 2026-02-09. Pinned exactly: an ad SDK minor release is a change to
  # a native dependency graph, and the way it breaks is at one platform's link
  # step only. Keep it equal to the exact pin in kidoz_ads/Package.swift.
  s.dependency 'KidozSDK', '10.1.5'

  # Kidoz's own README: iOS 11.0 and above. 13.0 here because that is the floor
  # the apps consuming this already set, and nothing is gained by supporting
  # further back than the app does.
  s.platform = :ios, '13.0'
  s.static_framework = true

  # Flutter.framework does not contain an i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
