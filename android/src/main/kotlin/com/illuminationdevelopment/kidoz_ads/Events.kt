package com.illuminationdevelopment.kidoz_ads

import net.kidoz.sdk.KidozError

/**
 * How this plugin hands an event back to Dart: the ad's id, an event name, and
 * whatever extra payload that event carries.
 */
internal typealias EventSink = (adId: Int, event: String, arguments: Map<String, Any?>) -> Unit

/**
 * This package's own error codes. Kidoz has none of its own to pass through.
 *
 * `KidozError` exposes `getMessage()` and `toString()` and no status enum —
 * Kidoz's own sample app reads nothing else from it. So the distinction a
 * caller actually needs (is this an empty auction, or did something break?)
 * has to be made here, from *which callback fired*, because that is the only
 * place the information exists.
 */
internal object KidozErrorCode {
    /** A load callback failed. The signal to fall through to another network. */
    const val NO_FILL = "NO_FILL"

    /** The ad loaded and then failed to present. */
    const val SHOW_FAILED = "SHOW_FAILED"

    /** A load was attempted before `Kidoz.initialize` completed. */
    const val NOT_INITIALIZED = "NOT_INITIALIZED"

    /** This plugin's own faults, and anything unclassified. */
    const val INTERNAL_ERROR = "INTERNAL_ERROR"
}

/**
 * Kidoz's failure, flattened into the shape `KidozAdError.fromMap` expects.
 *
 * [code] is supplied by the call site rather than read off the error, for the
 * reason given on [KidozErrorCode]. The message is passed through untouched and
 * is documented in Dart as something never to branch on.
 */
internal fun KidozError?.toEventMap(code: String): Map<String, Any?> = mapOf(
    "code" to code,
    // getMessage() is nullable and has been observed empty where toString()
    // carries the detail, so both are tried before giving up.
    "message" to (this?.message?.takeIf { it.isNotBlank() }
        ?: this?.toString()
        ?: "No message provided"),
)
