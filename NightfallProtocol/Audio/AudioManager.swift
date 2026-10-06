import Foundation
import Observation
import AVFoundation

@MainActor
@Observable
final class AudioManager {
    var soundEnabled = UserDefaults.standard.object(forKey: "nightfall.sound") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "nightfall.sound")
            if !soundEnabled { effect?.stop() }
        }
    }
    var musicEnabled = UserDefaults.standard.object(forKey: "nightfall.music") as? Bool ?? true {
        didSet { UserDefaults.standard.set(musicEnabled, forKey: "nightfall.music") }
    }
    private var effect: AVAudioPlayer?
    private var ambience: AVAudioPlayer?

    private func tone(frequency: Double, duration: Double, pulse: Bool) -> Data {
        let rate = 22_050
        let count = Int(Double(rate) * duration)
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + count * 2))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16))
        append(UInt16(1)); append(UInt16(1)); append(UInt32(rate))
        append(UInt32(rate * 2)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(count * 2))
        for index in 0..<count {
            let time = Double(index) / Double(rate)
            let fade = min(1, time * 20) * min(1, (duration - time) * 20)
            let envelope = pulse ? fade * exp(-time * 6) : fade
            let sample = (sin(time * frequency * .pi * 2) + sin(time * frequency * 1.5 * .pi * 2) * 0.2) * envelope * 4_000
            append(Int16(sample))
        }
        return data
    }

    func playInterfacePulse() {
        guard soundEnabled else { return }
        effect = try? AVAudioPlayer(data: tone(frequency: 440, duration: 0.15, pulse: true))
        effect?.volume = 0.35
        effect?.play()
    }

    func playCollapseStinger() {
        guard soundEnabled else { return }
        effect = try? AVAudioPlayer(data: tone(frequency: 90, duration: 0.7, pulse: true))
        effect?.volume = 0.5
        effect?.play()
    }

    func setMusicEnabled(_ enabled: Bool) {
        musicEnabled = enabled
        if enabled {
            if ambience == nil {
                try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
                ambience = try? AVAudioPlayer(data: tone(frequency: 55, duration: 4, pulse: false))
                ambience?.numberOfLoops = -1
                ambience?.volume = 0.12
            }
            ambience?.play()
        } else {
            ambience?.pause()
        }
    }

    func suspend() {
        ambience?.pause()
        effect?.stop()
    }
}
