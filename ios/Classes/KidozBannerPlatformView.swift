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
        banner.delegate = self
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
