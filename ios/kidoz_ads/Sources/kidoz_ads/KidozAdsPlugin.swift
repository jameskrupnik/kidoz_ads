import Flutter
import KidozSDK
import UIKit

/// This package's own error codes. Kidoz has none of its own to pass through.
///
/// `KidozError` exposes a description and no status enum — Kidoz's own sample
/// app reads nothing else from it. So the distinction a caller actually needs
/// (is this an empty auction, or did something break?) has to be made here,
/// from *which delegate callback fired*, because that is the only place the
/// information exists. The names match the Android side exactly, so
/// `KidozAdError.code` means one thing in Dart.
enum KidozErrorCode {
    /// A load callback failed. The signal to fall through to another network.
    static let noFill = "NO_FILL"
    /// The ad loaded and then failed to present.
    static let showFailed = "SHOW_FAILED"
    /// A load was attempted before initialization completed.
    static let notInitialized = "NOT_INITIALIZED"
    /// This plugin's own faults, and anything unclassified.
    static let internalError = "INTERNAL_ERROR"
}

/// Flattens a Kidoz failure into the shape `KidozAdError.fromMap` expects.
func kidozEventMap(_ error: KidozError?, code: String) -> [String: Any?] {
    return [
        "code": code,
        "message": error?.description ?? "No message provided",
    ]
}

/// Bridges the Kidoz iOS SDK onto one method channel.
///
/// The iOS SDK's load entry points are **static** and hand the ad to the
/// delegate rather than returning it — `KidozInterstitialAd.load(delegate:)` —
/// so there is no object to key on until the load callback fires. Ads are
/// stashed in `fullScreenAds` against the id Dart minted *inside* that
/// callback, and each delegate closes over its id to do it.
///
/// `delegates` is a second dictionary rather than a property on the ad for the
/// usual UIKit reason: Kidoz holds its delegate weakly, so letting one go out
/// of scope means the ad loads and no callback ever arrives.
public class KidozAdsPlugin: NSObject, FlutterPlugin {

    private let channel: FlutterMethodChannel
    private var fullScreenAds: [Int: AnyObject] = [:]
    private var delegates: [Int: AnyObject] = [:]

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "kidoz_ads",
            binaryMessenger: registrar.messenger()
        )
        let instance = KidozAdsPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)

        registrar.register(
            KidozBannerViewFactory(messenger: registrar.messenger()) {
                [weak instance] adId, event, arguments in
                instance?.sendEvent(adId: adId, event: event, arguments: arguments)
            },
            withId: "kidoz_ads/banner"
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "initialize":
            initialize(arguments, result)
        case "loadFullScreenAd":
            loadFullScreenAd(arguments, result)
        case "showFullScreenAd":
            showFullScreenAd(arguments, result)
        case "disposeAd":
            if let adId = arguments["adId"] as? Int {
                fullScreenAds.removeValue(forKey: adId)
                delegates.removeValue(forKey: adId)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(_ arguments: [String: Any], _ result: @escaping FlutterResult) {
        guard
            let publisherId = arguments["publisherId"] as? String, !publisherId.isEmpty,
            let securityToken = arguments["securityToken"] as? String, !securityToken.isEmpty
        else {
            result(FlutterError(
                code: "INVALID_CREDENTIALS",
                message: "publisherId and securityToken must not be empty",
                details: nil
            ))
            return
        }

        let delegate = InitDelegate(result: result)
        // Held for the life of the process: Kidoz's init delegate is weak like
        // the rest, and initialization is one-way so there is nothing to
        // release it on.
        initDelegate = delegate

        Kidoz.instance.initialize(
            publisherID: publisherId,
            securityToken: securityToken,
            delegate: delegate
        )
    }

    private var initDelegate: InitDelegate?

    private func loadFullScreenAd(_ arguments: [String: Any], _ result: @escaping FlutterResult) {
        guard let adId = arguments["adId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "adId is required",
                details: nil
            ))
            return
        }

        // Checked here as well as in Dart: the Dart guard catches the ordinary
        // programming error, but a caller that raced initialize() would reach
        // a static load() that returns without ever calling back, and the
        // caller's chain would stall rather than falling through.
        guard Kidoz.instance.isSDKInitialized() else {
            sendEvent(
                adId: adId,
                event: "loadFailed",
                arguments: [
                    "code": KidozErrorCode.notInitialized,
                    "message": "Kidoz SDK is not initialized",
                ]
            )
            result(nil)
            return
        }

        let rewarded = arguments["rewarded"] as? Bool ?? false
        let store: (Int, AnyObject) -> Void = { [weak self] adId, ad in
            self?.fullScreenAds[adId] = ad
        }
        let forget: (Int) -> Void = { [weak self] adId in
            self?.fullScreenAds.removeValue(forKey: adId)
        }
        let send: (Int, String, [String: Any?]) -> Void = { [weak self] adId, event, arguments in
            self?.sendEvent(adId: adId, event: event, arguments: arguments)
        }

        if rewarded {
            let delegate = RewardedAdDelegate(
                adId: adId, store: store, forget: forget, sendEvent: send
            )
            delegates[adId] = delegate
            KidozRewardedAd.load(delegate: delegate)
        } else {
            let delegate = InterstitialAdDelegate(
                adId: adId, store: store, forget: forget, sendEvent: send
            )
            delegates[adId] = delegate
            KidozInterstitialAd.load(delegate: delegate)
        }
        result(nil)
    }

    private func showFullScreenAd(_ arguments: [String: Any], _ result: @escaping FlutterResult) {
        guard let adId = arguments["adId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "adId is required",
                details: nil
            ))
            return
        }

        guard let ad = fullScreenAds[adId] else {
            sendEvent(
                adId: adId,
                event: "showFailed",
                arguments: [
                    "code": KidozErrorCode.internalError,
                    "message": "Ad \(adId) is gone",
                ]
            )
            result(nil)
            return
        }

        guard let presenter = Self.topViewController() else {
            sendEvent(
                adId: adId,
                event: "showFailed",
                arguments: [
                    "code": KidozErrorCode.internalError,
                    "message": "No view controller available to present from",
                ]
            )
            result(nil)
            return
        }

        // isLoaded() is checked because show() on a spent or unloaded Kidoz ad
        // reports nothing at all — no delegate callback — which would leave the
        // caller's chain waiting on its own timeout.
        switch ad {
        case let interstitial as KidozInterstitialAd where interstitial.isLoaded():
            interstitial.show(viewController: presenter)
        case let rewarded as KidozRewardedAd where rewarded.isLoaded():
            rewarded.show(viewController: presenter)
        default:
            sendEvent(
                adId: adId,
                event: "showFailed",
                arguments: [
                    "code": KidozErrorCode.internalError,
                    "message": "Ad \(adId) is not ready",
                ]
            )
        }
        result(nil)
    }

    fileprivate func sendEvent(adId: Int, event: String, arguments: [String: Any?]) {
        var payload = arguments
        payload["adId"] = adId
        payload["event"] = event
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onAdEvent", arguments: payload)
        }
    }

    /// The frontmost view controller, walking past anything already presented.
    ///
    /// Presenting from a controller that is itself covered throws a UIKit
    /// warning and shows nothing, which is easy to hit when an ad is triggered
    /// from a Flutter route shown over a native modal.
    static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController

        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// Reports the one-shot outcome of `Kidoz.instance.initialize` back to Dart.
final class InitDelegate: NSObject, KidozInitDelegate {

    private var result: FlutterResult?

    init(result: @escaping FlutterResult) {
        self.result = result
        super.init()
    }

    func onInitSuccess() {
        // Nulled after firing: a FlutterResult must be called exactly once, and
        // an SDK that reported both success and failure would otherwise crash
        // the engine rather than the ad.
        result?(nil)
        result = nil
    }

    func onInitError(_ error: String) {
        result?(FlutterError(code: "INIT_FAILED", message: error, details: nil))
        result = nil
    }
}

/// One interstitial's delegate, tagged with the id its events belong to.
final class InterstitialAdDelegate: NSObject, KidozInterstitialDelegate {

    private let adId: Int
    private let store: (Int, AnyObject) -> Void
    private let forget: (Int) -> Void
    private let sendEvent: (Int, String, [String: Any?]) -> Void

    init(
        adId: Int,
        store: @escaping (Int, AnyObject) -> Void,
        forget: @escaping (Int) -> Void,
        sendEvent: @escaping (Int, String, [String: Any?]) -> Void
    ) {
        self.adId = adId
        self.store = store
        self.forget = forget
        self.sendEvent = sendEvent
        super.init()
    }

    func onInterstitialAdLoaded(kidozInterstitialAd: KidozInterstitialAd) {
        store(adId, kidozInterstitialAd)
        sendEvent(adId, "loaded", [:])
    }

    func onInterstitialAdFailedToLoad(kidozError: KidozError) {
        sendEvent(adId, "loadFailed", kidozEventMap(kidozError, code: KidozErrorCode.noFill))
    }

    func onInterstitialAdShown(kidozInterstitialAd: KidozInterstitialAd) {
        sendEvent(adId, "shown", [:])
    }

    func onInterstitialAdFailedToShow(
        kidozInterstitialAd: KidozInterstitialAd,
        kidozError: KidozError
    ) {
        forget(adId)
        sendEvent(adId, "showFailed", kidozEventMap(kidozError, code: KidozErrorCode.showFailed))
    }

    func onInterstitialImpression(kidozInterstitialAd: KidozInterstitialAd) {
        sendEvent(adId, "impression", [:])
    }

    func onInterstitialAdClosed(kidozInterstitialAd: KidozInterstitialAd) {
        forget(adId)
        sendEvent(adId, "closed", [:])
    }
}

/// One rewarded ad's delegate, tagged with the id its events belong to.
final class RewardedAdDelegate: NSObject, KidozRewardedDelegate {

    private let adId: Int
    private let store: (Int, AnyObject) -> Void
    private let forget: (Int) -> Void
    private let sendEvent: (Int, String, [String: Any?]) -> Void

    init(
        adId: Int,
        store: @escaping (Int, AnyObject) -> Void,
        forget: @escaping (Int) -> Void,
        sendEvent: @escaping (Int, String, [String: Any?]) -> Void
    ) {
        self.adId = adId
        self.store = store
        self.forget = forget
        self.sendEvent = sendEvent
        super.init()
    }

    func onRewardedAdLoaded(kidozRewardedAd: KidozRewardedAd) {
        store(adId, kidozRewardedAd)
        sendEvent(adId, "loaded", [:])
    }

    func onRewardedAdFailedToLoad(kidozError: KidozError) {
        sendEvent(adId, "loadFailed", kidozEventMap(kidozError, code: KidozErrorCode.noFill))
    }

    func onRewardedAdShown(kidozRewardedAd: KidozRewardedAd) {
        sendEvent(adId, "shown", [:])
    }

    func onRewardedAdFailedToShow(kidozRewardedAd: KidozRewardedAd, kidozError: KidozError) {
        forget(adId)
        sendEvent(adId, "showFailed", kidozEventMap(kidozError, code: KidozErrorCode.showFailed))
    }

    /// Fires before `onRewardedAdClosed`, which is what lets a caller treat
    /// closure as terminal and still know whether a reward was earned.
    ///
    /// Kidoz passes no reward payload — no name, no amount — because there is
    /// no dashboard field to configure one. The reward is the signal.
    func onRewardReceived(kidozRewardedAd: KidozRewardedAd) {
        sendEvent(adId, "rewardReceived", [:])
    }

    func onRewardedImpression(kidozRewardedAd: KidozRewardedAd) {
        sendEvent(adId, "impression", [:])
    }

    func onRewardedAdClosed(kidozRewardedAd: KidozRewardedAd) {
        forget(adId)
        sendEvent(adId, "closed", [:])
    }
}
