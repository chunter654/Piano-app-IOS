import AVFoundation
import Foundation

/// Configures `AVAudioSession` so the piano sounds *alongside* whatever else is
/// playing, and reports the system events the engine has to react to.
///
/// The whole mixing behaviour comes from one supported choice: the `.playback`
/// category with the `.mixWithOthers` option. That is Apple's sanctioned way to
/// say "let me make sound without silencing anyone else". This app never asks
/// for an exclusive session and never ducks other audio.
final class AudioSessionManager {

    enum Event {
        case interruptionBegan
        case interruptionEnded(shouldResume: Bool)
        case routeChanged(outputDeviceLost: Bool)
        case mediaServicesWereReset
    }

    /// A hint, not a guarantee. iOS grants what the hardware and the current
    /// route allow; the granted value is readable from `ioBufferDuration`.
    private static let preferredIOBufferDuration: TimeInterval = 0.005
    private static let preferredSampleRate: Double = 48_000

    /// Delivered on the main queue.
    var onEvent: ((Event) -> Void)?

    private let session = AVAudioSession.sharedInstance()
    private var observers: [NSObjectProtocol] = []

    /// The granted hardware buffer, in seconds. Useful for diagnosing latency.
    var ioBufferDuration: TimeInterval { session.ioBufferDuration }

    func configure() throws {
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        // Latency hints are best effort: a refused hint must not stop the app.
        try? session.setPreferredIOBufferDuration(Self.preferredIOBufferDuration)
        try? session.setPreferredSampleRate(Self.preferredSampleRate)
        registerObservers()
    }

    func activate() throws {
        try session.setActive(true)
    }

    func deactivate() {
        // Deliberately without `.notifyOthersOnDeactivation`: this app never
        // interrupted anybody, so there is no one waiting for a cue to resume.
        try? session.setActive(false)
    }

    private func registerObservers() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default

        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil,
                                            queue: .main) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            switch type {
            case .began:
                self?.onEvent?(.interruptionBegan)
            case .ended:
                let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                self?.onEvent?(.interruptionEnded(shouldResume: options.contains(.shouldResume)))
            @unknown default:
                break
            }
        })

        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: nil,
                                            queue: .main) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            let reason = raw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            self?.onEvent?(.routeChanged(outputDeviceLost: reason == .oldDeviceUnavailable))
        })

        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                            object: nil,
                                            queue: .main) { [weak self] _ in
            self?.onEvent?(.mediaServicesWereReset)
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
