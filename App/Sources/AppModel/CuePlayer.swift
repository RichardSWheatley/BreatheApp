import AVFoundation
import BreatheKit
import Foundation

/// Plays tones, spoken prompts and haptics, and keeps the audio session
/// alive so guidance continues with the screen off.
@MainActor
final class CuePlayer: CueSink {
    private let audioEngine = AVAudioEngine()
    private let tonePlayer = AVAudioPlayerNode()
    private let keepAlivePlayer = AVAudioPlayerNode()
    private let synthesizer = AVSpeechSynthesizer()
    private let haptics = HapticPlayer()
    private let format: AVAudioFormat
    private var toneBuffers: [Tone: AVAudioPCMBuffer] = [:]
    private var keepAliveBuffer: AVAudioPCMBuffer?
    private let voice = AVSpeechSynthesisVoice(language: "en-US")

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
            ?? AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        audioEngine.attach(tonePlayer)
        audioEngine.attach(keepAlivePlayer)
        audioEngine.connect(tonePlayer, to: audioEngine.mainMixerNode, format: format)
        audioEngine.connect(keepAlivePlayer, to: audioEngine.mainMixerNode, format: format)
        for tone in Tone.allCases {
            toneBuffers[tone] = ToneSynthesizer.buffer(for: tone, format: format)
        }
        keepAliveBuffer = ToneSynthesizer.silence(seconds: 1, format: format)
    }

    func sessionWillStart() {
        configureAudioSession()
        startEngineIfNeeded()
        if let keepAliveBuffer {
            keepAlivePlayer.scheduleBuffer(keepAliveBuffer, at: nil, options: .loops)
            keepAlivePlayer.play()
        }
        haptics.prepare()
    }

    func sessionDidEnd() {
        synthesizer.stopSpeaking(at: .immediate)
        tonePlayer.stop()
        keepAlivePlayer.stop()
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func play(_ cue: Cue) {
        switch cue {
        case .tone(let tone):
            guard let buffer = toneBuffers[tone] else { return }
            startEngineIfNeeded()
            tonePlayer.scheduleBuffer(buffer, at: nil, options: .interrupts)
            if !tonePlayer.isPlaying {
                tonePlayer.play()
            }
        case .speak(let text):
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.prefersAssistiveTechnologySettings = false
            synthesizer.speak(utterance)
        case .haptic(let pattern):
            haptics.play(pattern)
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func startEngineIfNeeded() {
        guard !audioEngine.isRunning else { return }
        try? audioEngine.start()
    }
}
