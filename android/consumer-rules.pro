# Shipped with the AAR, so a consuming app gets these whether or not its own
# proguard-rules.pro is wired up. That matters: AGP 9 runs R8 on release by
# default, an app can reference no rules file at all without any build error,
# and the failure mode is a crash at launch in a release build that reviewers
# and CI never see — long after the debug build everyone tested worked.
-keep class net.kidoz.** { *; }
-keep class kotlin.Metadata { *; }

# Kidoz renders its creatives in a WebView and reaches the bridge by name.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# The plugin's own entry points, reached reflectively by the Flutter embedding.
-keep class com.illuminationdevelopment.kidoz_ads.** { *; }
