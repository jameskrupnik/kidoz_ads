package com.illuminationdevelopment.kidoz_ads

import android.app.Activity
import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import net.kidoz.ads.banner.KidozBannerAdCallback
import net.kidoz.ads.banner.KidozBannerView
import net.kidoz.sdk.KidozError

/** Builds the [KidozBannerPlatformView]s that back `KidozBannerAd`. */
internal class KidozBannerViewFactory(
    private val activityProvider: () -> Activity?,
    private val sendEvent: EventSink,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any?>()
        return KidozBannerPlatformView(activityProvider(), params, sendEvent)
    }
}

/**
 * One `KidozBannerView`, embedded in the Flutter view hierarchy.
 *
 * ### Why the view-hierarchy path and not the programmatic one
 *
 * Kidoz's Android banner has two documented modes. The programmatic one takes
 * an Activity and a `Position.BOTTOM_CENTER`-style constant and **attaches
 * itself to the activity's window** — which, in a Flutter app, means it floats
 * over the whole `FlutterView` at a position Flutter knows nothing about,
 * ignoring the slot the widget tree reserved for it and surviving a route
 * change that should have taken it away.
 *
 * The other mode is for a banner declared in XML: call
 * `setLayoutWithoutShowing()`, then `load()`, then `show()` once it is ready.
 * Hosting the view inside this platform view *is* that case — the parent is
 * our container rather than an inflated layout — so that is the sequence used
 * here. `setLayoutWithoutShowing` is what stops it reaching for the window on
 * layout, and it is the single most load-bearing call in this file.
 *
 * ### Sizing
 *
 * Kidoz publishes no size API and no size table. The container is given the
 * frame Dart asked for, in device pixels converted here against the density of
 * the context the view is actually attached to — reusing a density Flutter
 * reported earlier puts the banner at the wrong size on a second display or
 * after a fold. The banner itself is added with `MATCH_PARENT` so it fills
 * whatever it is given rather than fighting it.
 */
internal class KidozBannerPlatformView(
    activity: Activity?,
    params: Map<*, *>,
    private val sendEvent: EventSink,
) : PlatformView {

    private val adId = (params["adId"] as? Number)?.toInt() ?: -1
    private val container: FrameLayout?
    private var banner: KidozBannerView? = null

    init {
        if (activity == null) {
            container = null
            sendEvent(
                adId,
                "loadFailed",
                mapOf(
                    "code" to KidozErrorCode.INTERNAL_ERROR,
                    "message" to "Kidoz banners need a foreground Activity; none is attached",
                ),
            )
        } else {
            val density = activity.resources.displayMetrics.density
            val widthPx = (((params["width"] as? Number)?.toFloat() ?: 320f) * density).toInt()
            val heightPx = (((params["height"] as? Number)?.toFloat() ?: 50f) * density).toInt()

            container = FrameLayout(activity).apply {
                layoutParams = ViewGroup.LayoutParams(widthPx, heightPx)
            }

            banner = KidozBannerView(activity).apply {
                setBannerCallback(BannerCallback())

                // Keeps the banner out of the activity window — see the class
                // comment. Without this it attaches itself over the whole
                // FlutterView and this container stays empty.
                setLayoutWithoutShowing()

                layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                )
                container.addView(this)
                load()
            }
        }
    }

    override fun getView(): View? = container

    override fun dispose() {
        banner?.close()
        banner = null
    }

    private inner class BannerCallback : KidozBannerAdCallback {
        /**
         * `show()` is called here rather than at load, because the XML path
         * requires the banner to be ready first and `setLayoutWithoutShowing`
         * has deliberately suppressed the automatic one.
         */
        override fun onAdLoaded() {
            banner?.show()
            sendEvent(adId, "loaded", emptyMap())
        }

        override fun onAdFailedToLoad(error: KidozError?) =
            sendEvent(adId, "loadFailed", error.toEventMap(KidozErrorCode.NO_FILL))

        override fun onAdShown() = Unit

        override fun onAdFailedToShow(error: KidozError?) =
            sendEvent(adId, "showFailed", error.toEventMap(KidozErrorCode.SHOW_FAILED))

        override fun onAdImpression() = sendEvent(adId, "impression", emptyMap())

        override fun onAdClosed() = sendEvent(adId, "closed", emptyMap())
    }
}
