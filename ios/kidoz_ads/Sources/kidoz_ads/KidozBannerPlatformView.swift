import Flutter
import KidozSDK
import UIKit

/// Builds the platform views that back `KidozBannerAd`.
final class KidozBannerViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger
    private let sendEvent: (Int, String, [String: Any?]) -> Void

    init(
        messenger: FlutterBinaryMessenger,
        sendEvent: @escaping (Int, String, [String: Any?]) -> Void
    ) {
        self.messenger = messenger
        self.sendEvent = sendEvent
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return KidozBannerPlatformView(
            frame: frame,
            params: args as? [String: Any] ?? [:],
            sendEvent: sendEvent
        )
    }
}

/// One `KidozBannerView`, embedded in the Flutter view hierarchy.
///
/// ### Sizing
///
/// iOS takes the banner size from the frame in points, which is the same unit
/// Flutter's logical pixels are — so unlike Android there is no density
/// conversion here. Kidoz publishes no size table; its own sample constrains
/// the view to 320×50 and that is this package's default.
///
/// The banner is pinned to the container with autoresizing rather than given a
/// fixed frame, because a Flutter platform view is re-laid-out by the host
/// whenever the widget's constraints change and a banner holding a stale frame
/// would simply sit at the old size inside the new slot.
///
/// ### Why the delegate is a separate object
///
/// `KidozBannerView.delegate` is a **strong** property — its declaration in
/// KidozSDK's `.swiftinterface` carries no `weak`. With this class as the
/// delegate, the banner (held through `container`) held this class back, so
/// neither was ever freed: `deinit` never ran, `close()` was never called,
/// and every banner a route ever showed stayed alive off screen with its
/// WebView. `KidozBannerDelegateProxy` holds this class weakly instead, which
/// lets Flutter's release of the platform view actually tear the banner down.
final class KidozBannerPlatformView: NSObject, FlutterPlatformView, KidozBannerDelegate {

    private let adId: Int
    private let sendEvent: (Int, String, [String: Any?]) -> Void
    private let container: UIView
    private var banner: KidozBannerView?

    init(
        frame: CGRect,
        params: [String: Any],
        sendEvent: @escaping (Int, String, [String: Any?]) -> Void
    ) {
        self.adId = params["adId"] as? Int ?? -1
        self.sendEvent = sendEvent

        let width = (params["width"] as? NSNumber)?.doubleValue ?? 320
        let height = (params["height"] as? NSNumber)?.doubleValue ?? 50
        let bannerFrame = CGRect(x: 0, y: 0, width: width, height: height)

        self.container = UIView(frame: bannerFrame)
        super.init()

        guard Kidoz.instance.isSDKInitialized() else {
            sendEvent(
                adId,
                "loadFailed",
                [
                    "code": KidozErrorCode.notInitialized,
                    "message": "Kidoz SDK is not initialized",
                ]
            )
            return
        }

        let banner = KidozBannerView()
        let proxy = KidozBannerDelegateProxy(owner: self)
        banner.delegate = proxy
        banner.frame = bannerFrame
        banner.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        self.banner = banner
        container.addSubview(banner)
        banner.load()
    }

    func view() -> UIView {
        return container
    }

    deinit {
        banner?.close()
    }

    // MARK: - KidozBannerDelegate

    func onBannerAdLoaded(kidozBannerView: KidozBannerView) {
        sendEvent(adId, "loaded", [:])
    }

    func onBannerAdFailedToLoad(kidozBannerView: KidozBannerView, error: KidozError) {
        sendEvent(adId, "loadFailed", kidozEventMap(error, code: KidozErrorCode.noFill))
    }

    func onBannerAdShown(kidozBannerView: KidozBannerView) {
        // Deliberately not forwarded. Android's banner has no matching callback
        // on the path this plugin uses, and an event that exists on one
        // platform only is worse than no event — a caller writes against it,
        // tests on the platform that has it, and ships the other one broken.
    }

    func onBannerAdFailedToShow(kidozBannerView: KidozBannerView, error: KidozError) {
        sendEvent(adId, "showFailed", kidozEventMap(error, code: KidozErrorCode.showFailed))
    }

    func onBannerAdImpression(kidozBannerView: KidozBannerView) {
        sendEvent(adId, "impression", [:])
    }

    func onBannerAdClosed(kidozBannerView: KidozBannerView) {
        sendEvent(adId, "closed", [:])
    }
}

/// Forwards a banner's delegate calls to a platform view it does not own.
///
/// See "Why the delegate is a separate object" on `KidozBannerPlatformView`.
/// The banner owns this proxy; the proxy only borrows the platform view, so the
/// ownership runs one way and the platform view can be freed.
final class KidozBannerDelegateProxy: NSObject, KidozBannerDelegate {

    private weak var owner: KidozBannerDelegate?

    init(owner: KidozBannerDelegate) {
        self.owner = owner
        super.init()
    }

    func onBannerAdLoaded(kidozBannerView: KidozBannerView) {
        owner?.onBannerAdLoaded(kidozBannerView: kidozBannerView)
    }

    func onBannerAdFailedToLoad(kidozBannerView: KidozBannerView, error: KidozError) {
        owner?.onBannerAdFailedToLoad(kidozBannerView: kidozBannerView, error: error)
    }

    func onBannerAdShown(kidozBannerView: KidozBannerView) {
        owner?.onBannerAdShown(kidozBannerView: kidozBannerView)
    }

    func onBannerAdFailedToShow(kidozBannerView: KidozBannerView, error: KidozError) {
        owner?.onBannerAdFailedToShow(kidozBannerView: kidozBannerView, error: error)
    }

    func onBannerAdImpression(kidozBannerView: KidozBannerView) {
        owner?.onBannerAdImpression(kidozBannerView: kidozBannerView)
    }

    func onBannerAdClosed(kidozBannerView: KidozBannerView) {
        owner?.onBannerAdClosed(kidozBannerView: kidozBannerView)
    }
}
