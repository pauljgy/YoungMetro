import AVFoundation
import Foundation

enum BeatSoundStoreError: LocalizedError {
    case fileNotFound
    case decodeFailed
    case conversionFailed
    case importFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "Beat sound file not found."
        case .decodeFailed: return "Could not decode the audio file."
        case .conversionFailed: return "Could not convert the audio to the required format."
        case .importFailed: return "Could not import the selected file."
        }
    }
}

final class BeatSoundStore {
    static let shared = BeatSoundStore()

    private let customBeatFilename = "custom_beat"
    private let customBeatNameKey = "customBeatDisplayName"

    private(set) var beatBuffer: AVAudioPCMBuffer?
    private(set) var customSoundName: String?

    private init() {
        customSoundName = UserDefaults.standard.string(forKey: customBeatNameKey)
        loadBeatBuffer()
    }

    var hasCustomSound: Bool {
        customBeatURL() != nil
    }

    // MARK: - Public API

    func loadBeatBuffer() {
        do {
            beatBuffer = try loadBuffer(from: resolveBeatURL())
        } catch {
            beatBuffer = try? loadBuffer(from: bundledDefaultURL())
        }
    }

    func importSound(from sourceURL: URL) throws {
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let ext = sourceURL.pathExtension.isEmpty ? "wav" : sourceURL.pathExtension
        let destination = documentsDirectory().appendingPathComponent("\(customBeatFilename).\(ext)")

        removeExistingCustomBeat()

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } catch {
            throw BeatSoundStoreError.importFailed
        }

        let displayName = sourceURL.lastPathComponent
        UserDefaults.standard.set(displayName, forKey: customBeatNameKey)
        customSoundName = displayName

        beatBuffer = try loadBuffer(from: destination)
    }

    func resetToDefault() throws {
        removeExistingCustomBeat()
        UserDefaults.standard.removeObject(forKey: customBeatNameKey)
        customSoundName = nil
        beatBuffer = try loadBuffer(from: bundledDefaultURL())
    }

    // MARK: - Private Helpers

    private func resolveBeatURL() -> URL {
        customBeatURL() ?? bundledDefaultURL()
    }

    private func customBeatURL() -> URL? {
        let documents = documentsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: documents,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        return files.first { $0.lastPathComponent.hasPrefix(customBeatFilename) }
    }

    private func bundledDefaultURL() -> URL {
        guard let url = Bundle.main.url(forResource: "default_click", withExtension: "wav") else {
            fatalError("default_click.wav missing from bundle")
        }
        return url
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func removeExistingCustomBeat() {
        guard let existing = customBeatURL() else { return }
        try? FileManager.default.removeItem(at: existing)
    }

    private func loadBuffer(from url: URL) throws -> AVAudioPCMBuffer {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw BeatSoundStoreError.fileNotFound
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else {
            throw BeatSoundStoreError.decodeFailed
        }

        do {
            try audioFile.read(into: buffer)
        } catch {
            throw BeatSoundStoreError.decodeFailed
        }

        return buffer
    }

    /// Converts the beat buffer to match the engine's output format (called once at engine setup).
    func buffer(matching format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let sourceBuffer = beatBuffer else { return nil }

        if sourceBuffer.format == format {
            return sourceBuffer
        }

        guard let converter = AVAudioConverter(from: sourceBuffer.format, to: format) else {
            return nil
        }

        let ratio = format.sampleRate / sourceBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputFrameCapacity) else {
            return nil
        }

        var error: NSError?
        var consumed = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if error != nil {
            return nil
        }

        return outputBuffer
    }
}
