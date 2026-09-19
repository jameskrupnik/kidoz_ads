package com.illuminationdevelopment.kidoz_ads

import android.app.Activity
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import net.kidoz.ads.fullscreen.interstial.KidozInterstitialAd
import net.kidoz.ads.fullscreen.interstial.KidozInterstitialAdCallback
import net.kidoz.ads.fullscreen.rewarded.KidozRewardedAd
import net.kidoz.ads.fullscreen.rewarded.KidozRewardedAdCallback
import net.kidoz.sdk.Kidoz
import net.kidoz.sdk.KidozError
import net.kidoz.sdk.KidozInitializationListener

/**
 * Bridges the Kidoz Android SDK onto one method channel.
 *
 * Three constraints from the SDK shape everything here:
 *
 *  - **`Kidoz.initialize` takes an Activity, not an application Context**, and
 *    the SDK's own docs say to call it from `MainActivity.onCreate`. A Flutter
 *    plugin attaches to the engine before it attaches to an activity, so
 *    `initialize` has to fail loudly when no activity is bound rather than
 *    quietly passing the application context and getting a WebView that cannot
 *    present.
 *  - **The load entry points are static and hand the ad to the callback**
 *    (`KidozInterstitialAd.load(activity, callback)`), so there is no object to
 *    key on until `onAdLoaded` fires. Ads are therefore stashed in
 *    [fullScreenAds] against the id Dart minted *inside* that callback, and the
 *    callback closes over the id to do it.
 *  - Kidoz's callbacks are not documented as main-thread-only, but its views
 *    are WebViews. Every entry point hops to the main looper rather than
 *    trusting the caller, because Flutter guarantees method calls arrive on the
 *    platform thread and says nothing about which thread that is.
 */
class KidozAdsPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    /**
     * Loaded ads, by the id Dart minted. The value is `Any` because Kidoz's two
     * full-screen types share no supertype worth naming — `show()` is declared
     * separately on each — so the cast happens at the one place that shows.
     */
    private val fullScreenAds = mutableMapOf<Int, Any>()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)

        binding.platformViewRegistry.registerViewFactory(
            BANNER_VIEW_TYPE,
            KidozBannerViewFactory({ activity }) { adId, event, arguments ->
                sendEvent(adId, event, arguments)
            },
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        mainHandler.post { fullScreenAds.clear() }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "loadFullScreenAd" -> loadFullScreenAd(call, result)
            "showFullScreenAd" -> showFullScreenAd(call, result)
            "disposeAd" -> {
                val adId = call.argument<Int>("adId")
                mainHandler.post { adId?.let(fullScreenAds::remove) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        val publisherId = call.argument<String>("publisherId")
        val securityToken = call.argument<String>("securityToken")

        if (publisherId.isNullOrBlank() || securityToken.isNullOrBlank()) {
            result.error(
                "INVALID_CREDENTIALS",
                "publisherId and securityToken must not be empty",
                null,
            )
            return
        }

        // Kidoz needs a foreground Activity to initialize. Reporting it here
        // means the caller learns while it can still fall through to another
        // network, rather than at the first load.
        val activity = this.activity ?: run {
            result.error(
                "NO_ACTIVITY",
                "Kidoz.initialize needs a foreground Activity; none is attached",
                null,
            )
            return
        }

        mainHandler.post {
            Kidoz.initialize(
                activity,
                publisherId,
                securityToken,
                object : KidozInitializationListener {
                    override fun onInitSuccess() {
                        result.success(null)
                    }

                    override fun onInitError(error: KidozError) {
                        result.error(
                            "INIT_FAILED",
                            error.message ?: "Kidoz SDK failed to initialize",
                            null,
                        )
                    }
                },
            )
        }
    }

    private fun loadFullScreenAd(call: MethodCall, result: MethodChannel.Result) {
        val adId = call.argument<Int>("adId")
        val rewarded = call.argument<Boolean>("rewarded") ?: false

        if (adId == null) {
            result.error("INVALID_ARGUMENTS", "adId is required", null)
            return
        }

        val activity = this.activity ?: run {
            result.error(
                "NO_ACTIVITY",
                "Kidoz full-screen ads need a foreground Activity; none is attached",
                null,
            )
            return
        }

        mainHandler.post {
            if (rewarded) {
                KidozRewardedAd.load(activity, RewardedCallback(adId))
            } else {
                KidozInterstitialAd.load(activity, InterstitialCallback(adId))
            }
        }
        result.success(null)
    }

    private fun showFullScreenAd(call: MethodCall, result: MethodChannel.Result) {
        val adId = call.argument<Int>("adId")
        if (adId == null) {
            result.error("INVALID_ARGUMENTS", "adId is required", null)
            return
        }

        mainHandler.post {
            when (val ad = fullScreenAds[adId]) {
                null -> sendEvent(
                    adId,
                    "showFailed",
                    mapOf(
                        "code" to KidozErrorCode.INTERNAL_ERROR,
                        "message" to "Ad $adId is gone",
                    ),
                )
                is KidozInterstitialAd -> ad.show()
                is KidozRewardedAd -> ad.show()
                else -> sendEvent(
                    adId,
                    "showFailed",
                    mapOf(
                        "code" to KidozErrorCode.INTERNAL_ERROR,
                        "message" to "Ad $adId has an unexpected type",
                    ),
                )
            }
        }
        result.success(null)
    }

    /** Bridges one interstitial's callbacks onto [sendEvent]. */
    private inner class InterstitialCallback(private val adId: Int) :
        KidozInterstitialAdCallback {

        override fun onAdLoaded(ad: KidozInterstitialAd) {
            fullScreenAds[adId] = ad
            sendEvent(adId, "loaded")
        }

        override fun onAdFailedToLoad(error: KidozError) =
            sendEvent(adId, "loadFailed", error.toEventMap(KidozErrorCode.NO_FILL))

        override fun onAdShown(ad: KidozInterstitialAd) = sendEvent(adId, "shown")

        override fun onAdFailedToShow(ad: KidozInterstitialAd, error: KidozError) {
            fullScreenAds.remove(adId)
            sendEvent(adId, "showFailed", error.toEventMap(KidozErrorCode.SHOW_FAILED))
        }

        override fun onAdImpression(ad: KidozInterstitialAd) = sendEvent(adId, "impression")

        override fun onAdClosed(ad: KidozInterstitialAd) {
            // Kidoz's own sample nulls its reference here, and the SDK requires
            // a fresh load to show again. Dropping it now means a stray show()
            // reports "Ad is gone" rather than failing silently inside the SDK.
            fullScreenAds.remove(adId)
            sendEvent(adId, "closed")
        }
    }

    /** Bridges one rewarded ad's callbacks onto [sendEvent]. */
    private inner class RewardedCallback(private val adId: Int) : KidozRewardedAdCallback {

        override fun onAdLoaded(ad: KidozRewardedAd) {
            fullScreenAds[adId] = ad
            sendEvent(adId, "loaded")
        }

        override fun onAdFailedToLoad(error: KidozError) =
            sendEvent(adId, "loadFailed", error.toEventMap(KidozErrorCode.NO_FILL))

        override fun onAdShown(ad: KidozRewardedAd) = sendEvent(adId, "shown")

        override fun onAdFailedToShow(ad: KidozRewardedAd, error: KidozError) {
            fullScreenAds.remove(adId)
            sendEvent(adId, "showFailed", error.toEventMap(KidozErrorCode.SHOW_FAILED))
        }

        override fun onAdImpression(ad: KidozRewardedAd) = sendEvent(adId, "impression")

        /**
         * Fires before [onAdClosed], which is what lets a caller treat closure
         * as terminal and still know whether a reward was earned.
         *
         * Kidoz passes no reward payload — no name, no amount — because there
         * is no dashboard field to configure one. The reward is the signal.
         */
        override fun onRewardReceived(ad: KidozRewardedAd) = sendEvent(adId, "rewardReceived")

        override fun onAdClosed(ad: KidozRewardedAd) {
            fullScreenAds.remove(adId)
            sendEvent(adId, "closed")
        }
    }

    private fun sendEvent(
        adId: Int,
        event: String,
        arguments: Map<String, Any?> = emptyMap(),
    ) {
        val payload = HashMap<String, Any?>(arguments).apply {
            put("adId", adId)
            put("event", event)
        }
        mainHandler.post { channel.invokeMethod("onAdEvent", payload) }
    }

    private companion object {
        const val CHANNEL_NAME = "kidoz_ads"
        const val BANNER_VIEW_TYPE = "kidoz_ads/banner"
    }
}
