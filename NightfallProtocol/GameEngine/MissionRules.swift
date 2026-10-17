import Foundation

/// Mission progression is independent of loot, score and rendering.
struct MissionRules {
    enum Kind: String, CaseIterable {
        case recoverMemoryFragment, extractDreamArtifact, sealNightmareRift
        case rescueLostEcho, surviveUntilExtraction, investigateBlackSite
    }

    let kind: Kind
    private(set) var completed = 0
    private(set) var elapsed: Double = 0
    private(set) var channel: Double = 0
    private(set) var activated = false
    private(set) var scanned: Set<Int> = []
    var ready: Bool { completed == 2 }

    var instructionKey: String {
        if ready { return "mission.play.extract" }
        return "mission.play.\(kind.rawValue).\(completed)"
    }

    mutating func interact(station: Int) {
        guard !ready else { return }
        switch kind {
        case .recoverMemoryFragment, .extractDreamArtifact:
            if completed == 0, station == 0 { completed = 1 }
            else if completed == 1, station == 1 { activated = true }
        case .sealNightmareRift:
            if completed == 0, station == 0 { completed = 1 }
            else if completed == 1, station == 1 { activated = true }
        case .rescueLostEcho:
            if completed == 0, station == 0 { completed = 1 }
        case .surviveUntilExtraction:
            if completed == 1, station == 0 { completed = 2 }
        case .investigateBlackSite:
            if completed == 0, (0...1).contains(station) {
                scanned.insert(station)
                if scanned.count == 2 { completed = 1 }
            } else if completed == 1, station == 2 { completed = 2 }
        }
    }

    mutating func tick(seconds: Double, atChannelStation: Bool, echoAtExit: Bool) {
        guard !ready else { return }
        elapsed += max(0, seconds)
        switch kind {
        case .recoverMemoryFragment, .extractDreamArtifact, .sealNightmareRift:
            guard activated else { return }
            if atChannelStation {
                channel += max(0, seconds)
                let duration: Double = kind == .sealNightmareRift ? 8 : (kind == .extractDreamArtifact ? 5 : 3)
                if channel >= duration { completed = 2; activated = false }
            } else {
                channel = 0
                activated = false
            }
        case .rescueLostEcho:
            if completed == 1, echoAtExit { completed = 2 }
        case .surviveUntilExtraction:
            if elapsed >= 30 { completed = max(completed, 1) }
        case .investigateBlackSite: break
        }
    }

    mutating func interrupt() {
        channel = 0
        activated = false
    }
}

enum NightmareCondition: String, CaseIterable {
    case blackout, glassMaze, hunted, redSignal, echoTrail, zeroHour

    init(titleKey: String) {
        self = Self(rawValue: titleKey.split(separator: ".").dropFirst().first.map(String.init) ?? "") ?? .blackout
    }

    var collapseRate: Double { self == .zeroHour ? 1.35 : 1 }
    var exitInterval: Double { self == .glassMaze ? 0.14 : 0.24 }
    var pursuitThreshold: Double { self == .hunted ? 0.2 : 0.58 }
    var echoDelay: Int { self == .echoTrail ? 10 : 25 }
}

/// A sounding buys information, but leaves a transmission for entities to investigate.
/// Time is advanced by the scene, so pausing never recharges or expires a transmission.
struct FieldReceiver: Equatable {
    private(set) var charge: Double = 1
    private(set) var revealRemaining: Double = 0
    private(set) var traceRemaining: Double = 0
    private(set) var isSilent = false
    private(set) var transmissions = 0

    var canSound: Bool { charge >= 1 && !isSilent }
    var movementScale: Double { isSilent ? 0.6 : 1 }
    var detectionScale: Double { isSilent ? 0.55 : 1 }
    func canBeHeard(distance: Double, detectionRadius: Double) -> Bool {
        distance < detectionRadius * detectionScale
    }

    @discardableResult mutating func sound() -> Bool {
        guard canSound else { return false }
        charge = 0
        revealRemaining = 4
        traceRemaining = 7
        transmissions += 1
        return true
    }

    mutating func toggleSilent() { isSilent.toggle() }

    mutating func tick(seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        charge = min(1, charge + seconds / 14)
        revealRemaining = max(0, revealRemaining - seconds)
        traceRemaining = max(0, traceRemaining - seconds)
    }
}
