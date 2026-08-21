import AVFoundation
import Combine
import Foundation

@MainActor
final class MetronomeEngine: ObservableObject {
    @Published var bpm: Double = 175 {
        didSet {
            let clamped = min(max(bpm, Self.minBPM), Self.maxBPM)
            if clamped != bpm {
                bpm = clamped
                return
            }
            if isPlaying {
                rescheduleForBPMChange()
            }
        }
    }

    @Published private(set) var isPlaying = false
    @Published private(set) var customSoundName: String?

    static let minBPM: Double = 100
    static let maxBPM: Double = 200

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let soundStore = BeatSoundStore.shared

    private var beatBuffer: AVAudioPCMBuffer?
    private var nextBeatIndex: Int = 0
    private var sampleRate: Double = 44100
    private var shouldResumeAfterInterruption = false
    private var schedulingActive = false
    private var interruptionObserver: NSObjectProtocol?

    private let beatsToScheduleAhead = 8

    init() {
        customSoundName = soundStore.customSoundName
        setupAudioGraph()
        observeInterruptions()
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    // MARK: - Public API

    func toggle() {
        isPlaying ? stop() : play()
    }

    func play() {
        do {
            try configureAudioSession()
            reloadBeatBuffer()
        } catch {
            return
        }

        guard let buffer = beatBuffer, buffer.frameLength > 0 else { return }

        engine.prepare()
        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            return
        }

        schedulingActive = false
        playerNode.stop()
        nextBeatIndex = 0
        schedulingActive = true

        // Schedule onto the player timeline starting at sample 0, then start
        // playback. Querying playerTime before play() returns nil and was
        // aborting start silently.
        scheduleBatch(count: beatsToScheduleAhead, buffer: buffer)
        playerNode.play()
        isPlaying = true
    }

    func stop() {
        schedulingActive = false
        playerNode.stop()

        if engine.isRunning {
            engine.pause()
        }

        nextBeatIndex = 0
        isPlaying = false
    }

    func importSound(from url: URL) async throws {
        let wasPlaying = isPlaying
        if wasPlaying { stop() }

        try soundStore.importSound(from: url)
        customSoundName = soundStore.customSoundName
        reloadBeatBuffer()

        if wasPlaying { play() }
    }

    func resetToDefaultSound() throws {
        let wasPlaying = isPlaying
        if wasPlaying { stop() }

        try soundStore.resetToDefault()
        customSoundName = nil
        reloadBeatBuffer()

        if wasPlaying { play() }
    }

    // MARK: - Audio Graph Setup

    private func setupAudioGraph() {
        engine.attach(playerNode)
        engine.mainMixerNode.outputVolume = 1.0
        playerNode.volume = 1.0
        reloadBeatBuffer()
    }

    private func reloadBeatBuffer() {
        soundStore.loadBeatBuffer()
        guard let source = soundStore.beatBuffer, source.frameLength > 0 else {
            beatBuffer = nil
            return
        }

        // Play in the click's own format. The mixer converts to hardware output.
        // Converting into outputNode.outputFormat (often 0 Hz before the session
        // is active, or a mismatched layout) produced a silent / unplayable buffer.
        let format = source.format
        sampleRate = format.sampleRate

        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        beatBuffer = source
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
    }

    // MARK: - Scheduling

    private var beatIntervalSamples: AVAudioFramePosition {
        max(1, AVAudioFramePosition((60.0 / bpm) * sampleRate))
    }

    private func scheduleBatch(count: Int, buffer: AVAudioPCMBuffer) {
        guard schedulingActive else { return }

        let interval = beatIntervalSamples
        let rate = sampleRate

        for i in 0..<count {
            let beatIndex = nextBeatIndex + i
            let sampleTime = AVAudioFramePosition(beatIndex) * interval
            let time = AVAudioTime(sampleTime: sampleTime, atRate: rate)
            let isLast = (i == count - 1)

            playerNode.scheduleBuffer(buffer, at: time, options: []) { [weak self] in
                Task { @MainActor in
                    guard let self, self.schedulingActive, isLast, let buffer = self.beatBuffer else { return }
                    self.scheduleBatch(count: self.beatsToScheduleAhead, buffer: buffer)
                }
            }
        }

        nextBeatIndex += count
    }

    private func rescheduleForBPMChange() {
        guard schedulingActive, let buffer = beatBuffer else { return }

        playerNode.stop()
        nextBeatIndex = 0
        scheduleBatch(count: beatsToScheduleAhead, buffer: buffer)
        playerNode.play()
    }

    // MARK: - Interruption Handling

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleInterruption(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            shouldResumeAfterInterruption = isPlaying
            stop()

        case .ended:
            guard shouldResumeAfterInterruption else { return }
            shouldResumeAfterInterruption = false

            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }

        @unknown default:
            break
        }
    }
}
