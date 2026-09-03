import AVFoundation
import BreatheKit

/// Renders the short guidance tones into PCM buffers at launch so playback
/// is instant and never depends on bundled audio assets.
enum ToneSynthesizer {
    struct Note {
        let startHz: Double
        let endHz: Double
        let duration: Double
        let amplitude: Double

        init(_ startHz: Double, to endHz: Double? = nil, duration: Double, amplitude: Double = 0.35) {
            self.startHz = startHz
            self.endHz = endHz ?? startHz
            self.duration = duration
            self.amplitude = amplitude
        }
    }

    static func notes(for tone: Tone) -> [Note] {
        switch tone {
        case .inhale: return [Note(440, duration: 0.14), Note(587, to: 660, duration: 0.24)]
        case .exhale: return [Note(660, duration: 0.14), Note(523, to: 440, duration: 0.24)]
        case .hold: return [Note(523, duration: 0.45, amplitude: 0.4)]
        case .release: return [Note(330, duration: 0.28, amplitude: 0.3)]
        case .tick: return [Note(880, duration: 0.05, amplitude: 0.3)]
        case .chime: return [Note(660, duration: 0.16), Note(880, duration: 0.16), Note(1320, duration: 0.35, amplitude: 0.3)]
        case .alert: return [Note(300, duration: 0.15, amplitude: 0.4), Note(300, duration: 0.15, amplitude: 0.4)]
        }
    }

    /// Gap inserted between notes so consecutive notes read as distinct.
    static let noteGap = 0.03
    static let attack = 0.01
    static let release = 0.03

    static func buffer(for tone: Tone, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        render(notes: notes(for: tone), format: format)
    }

    /// Silent buffer used to keep the audio session alive between cues so
    /// iOS keeps the app running while the screen is off.
    static func silence(seconds: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        if let channel = buffer.floatChannelData?[0] {
            channel.update(repeating: 0, count: Int(frames))
        }
        return buffer
    }

    static func render(notes: [Note], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let totalSeconds = notes.reduce(0) { $0 + $1.duration + noteGap }
        let frames = AVAudioFrameCount(totalSeconds * sampleRate)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }

        var cursor = 0
        for note in notes {
            let noteFrames = Int(note.duration * sampleRate)
            var phase = 0.0
            for i in 0..<noteFrames {
                let t = Double(i) / sampleRate
                let progress = noteFrames > 1 ? Double(i) / Double(noteFrames - 1) : 0
                let frequency = note.startHz + (note.endHz - note.startHz) * progress
                phase += 2 * .pi * frequency / sampleRate
                let envelope = min(1, t / attack, max(0, (note.duration - t) / release))
                channel[cursor + i] = Float(sin(phase) * note.amplitude * envelope)
            }
            cursor += noteFrames
            let gapFrames = Int(noteGap * sampleRate)
            for i in 0..<gapFrames where cursor + i < Int(frames) {
                channel[cursor + i] = 0
            }
            cursor += gapFrames
        }
        buffer.frameLength = AVAudioFrameCount(min(cursor, Int(frames)))
        return buffer
    }
}
