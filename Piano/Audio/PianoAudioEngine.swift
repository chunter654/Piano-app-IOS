import AVFoundation
import AudioToolbox
import Combine
import Foundation

enum PianoAudioError: LocalizedError, Equatable {
    case soundBankMissing
    case soundBankUnreadable(String)
    case sessionUnavailable(String)
    case engineFailedToStart(String)

    var errorDescription: String? {
        switch self {
        case .soundBankMissing:
            return "The piano sound is missing from this build."
        case .soundBankUnreadable:
            return "The piano sound could not be loaded."
        case .sessionUnavailable:
            return "Audio is unavailable right now."
        case .engineFailedToStart:
            return "The audio engine could not start."
        }
    }

    /// The underlying system message, kept out of the headline but available for
    /// the smaller line underneath it.
    var detail: String? {
        switch self {
        case .soundBankMissing:
            return nil
        case .soundBankUnreadable(let message),
             .sessionUnavailable(let message),
             .engineFailedToStart(let message):
            return message
        }
    }
}

/// The grand piano voice, built on `AVAudioEngine` and `AVAudioUnitSampler`.
///
/// `AVAudioUnitSampler` is Apple's polyphonic sampler. It owns voice allocation,
/// voice stealing and each note's release tail, so the whole touch path is one
/// MIDI call with nothing expensive in between: touch → MIDI note → sound.
final class PianoAudioEngine: ObservableObject {

    /// A touchscreen cannot measure how hard a key was struck, so every note is
    /// played at one musical velocity rather than being faked from touch area.
    static let velocity: UInt8 = 100

    private static let midiChannel: UInt8 = 0
    private static let soundBankName = "GrandPiano"
    /// Bank 0, program 0 of the bundled sound bank is its grand piano.
    private static let program: UInt8 = 0

    private static let allSoundOff: UInt8 = 120

    /// Published only on start-up and on failure. Note events never touch it, so
    /// playing the piano never causes a SwiftUI update.
    @Published private(set) var failure: PianoAudioError?

    private var engine = AVAudioEngine()
    private var sampler = AVAudioUnitSampler()
    private let session = AudioSessionManager()

    private var isRunning = false
    private var isConfigured = false

    /// The hardware buffer iOS actually granted, in seconds.
    var ioBufferDuration: TimeInterval { session.ioBufferDuration }

    init() {
        session.onEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    // MARK: - Lifecycle

    /// Safe to call repeatedly; does nothing once the engine is running.
    func startIfNeeded() {
        guard !isRunning else { return }
        do {
            try start()
            failure = nil
        } catch let error as PianoAudioError {
            failure = error
        } catch {
            failure = .engineFailedToStart(error.localizedDescription)
        }
    }

    /// Used by the error screen's Retry button.
    func restart() {
        teardown()
        startIfNeeded()
    }

    private func start() throws {
        do {
            try session.configure()
        } catch {
            throw PianoAudioError.sessionUnavailable(error.localizedDescription)
        }

        guard let url = Bundle.main.url(forResource: Self.soundBankName, withExtension: "sf2") else {
            throw PianoAudioError.soundBankMissing
        }

        if !isConfigured {
            engine.attach(sampler)
            engine.connect(sampler, to: engine.mainMixerNode, format: nil)
            do {
                try sampler.loadSoundBankInstrument(at: url,
                                                    program: Self.program,
                                                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                                    bankLSB: UInt8(kAUSampler_DefaultBankLSB))
            } catch {
                throw PianoAudioError.soundBankUnreadable(error.localizedDescription)
            }
            isConfigured = true
        }

        do {
            try session.activate()
            engine.prepare()
            try engine.start()
        } catch {
            throw PianoAudioError.engineFailedToStart(error.localizedDescription)
        }

        isRunning = true
        warmUp()
    }

    private func teardown() {
        stopAllSound()
        engine.stop()
        engine.reset()
        engine = AVAudioEngine()
        sampler = AVAudioUnitSampler()
        isConfigured = false
        isRunning = false
    }

    /// Plays and immediately stops a few inaudible notes so the first real key
    /// press does not pay to page in sample data.
    private func warmUp() {
        for midi in [36, 60, 84] {
            sampler.startNote(UInt8(midi), withVelocity: 1, onChannel: Self.midiChannel)
            sampler.stopNote(UInt8(midi), onChannel: Self.midiChannel)
        }
    }

    // MARK: - Playing

    func noteOn(_ midi: Int) {
        guard isRunning, (0...127).contains(midi) else { return }
        sampler.startNote(UInt8(midi), withVelocity: Self.velocity, onChannel: Self.midiChannel)
    }

    /// Never guarded on `isRunning`: a note-off must always get through, or a
    /// note held across a state change would be stranded.
    func noteOff(_ midi: Int) {
        guard isConfigured, (0...127).contains(midi) else { return }
        sampler.stopNote(UInt8(midi), onChannel: Self.midiChannel)
    }

    /// Cuts every voice immediately. Used when the app is about to lose the
    /// audio session, where a decay tail would be dropped mid-way anyway.
    func stopAllSound() {
        guard isConfigured else { return }
        sampler.sendController(Self.allSoundOff, withValue: 0, onChannel: Self.midiChannel)
    }

    // MARK: - App lifecycle

    func enterBackground() {
        guard isRunning else { return }
        stopAllSound()
        engine.pause()
        session.deactivate()
        isRunning = false
    }

    func enterForeground() {
        guard !isRunning else { return }
        guard isConfigured else {
            // The first foreground transition can arrive before the initial
            // start, and there is no graph to resume yet.
            startIfNeeded()
            return
        }
        resume()
    }

    // MARK: - System events

    private func handle(_ event: AudioSessionManager.Event) {
        switch event {
        case .interruptionBegan:
            // iOS has already stopped the engine. Drop held notes so nothing is
            // left sounding when the session comes back.
            stopAllSound()
            engine.pause()
            isRunning = false

        case .interruptionEnded(let shouldResume):
            if shouldResume { resume() }

        case .routeChanged(let outputDeviceLost):
            // Headphones pulled out: stop rather than blast through the speaker.
            if outputDeviceLost { stopAllSound() }
            if isRunning && !engine.isRunning { resume() }

        case .mediaServicesWereReset:
            // Every audio object is invalid after this. Rebuild from scratch.
            teardown()
            startIfNeeded()
        }
    }

    private func resume() {
        do {
            try session.activate()
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
            isRunning = true
            failure = nil
        } catch {
            isRunning = false
            failure = .engineFailedToStart(error.localizedDescription)
        }
    }
}
