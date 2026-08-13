import AVFAudio
import Foundation

final class CatSoundPlayer {
    enum Sound {
        case meow
        case bark
        case chirp
        case purr
        case grumble
    }

    static let shared = CatSoundPlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private var phase = 0.0

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.62
        try? engine.start()
    }

    func play(_ sound: Sound) {
        if !engine.isRunning {
            try? engine.start()
        }

        let buffer: AVAudioPCMBuffer
        switch sound {
        case .meow:
            buffer = makeMeow(duration: 0.68, start: 430, peak: 720, end: 320)
        case .bark:
            buffer = makeBark(duration: 0.34)
        case .chirp:
            buffer = makeMeow(duration: 0.27, start: 760, peak: 1_260, end: 880)
        case .purr:
            buffer = makePurr(duration: 1.55)
        case .grumble:
            buffer = makeMeow(duration: 0.48, start: 230, peak: 310, end: 155)
        }

        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    private func makeBark(duration: Double) -> AVAudioPCMBuffer {
        render(duration: duration) { progress, time in
            let frequency = 185 + 58 * sin(.pi * progress)
            self.phase += 2 * .pi * frequency / self.sampleRate
            let attack = min(1, progress / 0.06)
            let decay = pow(1 - progress, 1.65)
            let pulse = 0.72 + 0.28 * sin(2 * .pi * 34 * time)
            let voice = sin(self.phase) + 0.42 * sin(2 * self.phase) + 0.18 * sin(3 * self.phase)
            return 0.36 * attack * decay * pulse * voice
        }
    }

    private func makeMeow(duration: Double, start: Double, peak: Double, end: Double) -> AVAudioPCMBuffer {
        render(duration: duration) { progress, time in
            let frequency: Double
            if progress < 0.32 {
                let rise = sin((progress / 0.32) * .pi / 2)
                frequency = start + (peak - start) * rise
            } else {
                let fall = (progress - 0.32) / 0.68
                frequency = peak + (end - peak) * fall
            }

            self.phase += 2 * .pi * frequency / self.sampleRate
            let envelope = pow(sin(.pi * progress), 0.72)
            let voice = sin(self.phase)
                + 0.34 * sin(2 * self.phase + 0.15)
                + 0.13 * sin(3 * self.phase + 0.4)
            let vibrato = 0.88 + 0.12 * sin(2 * .pi * 7.2 * time)
            return 0.38 * envelope * vibrato * voice
        }
    }

    private func makePurr(duration: Double) -> AVAudioPCMBuffer {
        render(duration: duration) { progress, time in
            let frequency = 52 + 3.5 * sin(2 * .pi * 1.8 * time)
            self.phase += 2 * .pi * frequency / self.sampleRate
            let fade = pow(sin(.pi * progress), 0.42)
            let throatPulse = pow(0.5 + 0.5 * sin(2 * .pi * 23 * time), 2.5)
            let texture = sin(self.phase) + 0.38 * sin(2 * self.phase)
            let breath = Double.random(in: -1...1) * 0.035
            return fade * (0.2 + 0.34 * throatPulse) * texture + fade * breath
        }
    }

    private func render(
        duration: Double,
        sample: (_ progress: Double, _ time: Double) -> Double
    ) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        guard let samples = buffer.floatChannelData?[0] else { return buffer }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let progress = min(1, time / duration)
            samples[frame] = Float(max(-1, min(1, sample(progress, time))))
        }
        return buffer
    }
}
