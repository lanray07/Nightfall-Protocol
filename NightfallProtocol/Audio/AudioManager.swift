import Foundation
import Observation

@MainActor
@Observable
final class AudioManager {
    var soundEnabled = true
    var musicEnabled = true

    func playInterfacePulse() {
        guard soundEnabled else { return }
    }

    func playCollapseStinger() {
        guard soundEnabled else { return }
    }

    func setMusicEnabled(_ enabled: Bool) {
        musicEnabled = enabled
    }
}
