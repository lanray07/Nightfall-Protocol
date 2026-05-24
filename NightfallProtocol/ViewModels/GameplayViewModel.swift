import Foundation
import Combine
import SpriteKit

@MainActor
final class GameplayViewModel: ObservableObject {
    @Published var collapseLevel: Double = 0
    @Published var health: Double = 1
    @Published var sanity: Double = 1
    @Published var objectives: [ObjectiveState]
    @Published var inventory: [LootReward] = []
    @Published var currentRoomEvent: NightmareEvent?
    @Published var enemyWarningKey: String?
    @Published var extractionReady = false
    @Published var result: ExtractionSummary?
    @Published var eventCounter = 0
    @Published var runScore = 0
    @Published var momentumMultiplier = 1
    @Published var scorePulseKey: String?

    let mission: MissionPlan

    private let roomEventGenerator = RoomEventGenerator()
    private let lootGenerator = LootGenerator()
    private let loreGenerator = MissionLoreGenerator()
    private var timerTask: Task<Void, Never>?
    private var tickCount = 0

    init(mission: MissionPlan) {
        self.mission = mission
        objectives = mission.objectives
    }

    var collapsePercent: Int {
        Int(collapseLevel * 100)
    }

    var completedObjectiveCount: Int {
        objectives.filter(\.isCompleted).count
    }

    var allObjectivesComplete: Bool {
        objectives.allSatisfy(\.isCompleted)
    }

    var threatKey: String {
        if collapseLevel >= 0.88 {
            return "gameplay.threat.critical"
        }

        if collapseLevel >= 0.62 {
            return "gameplay.threat.severe"
        }

        if collapseLevel >= 0.34 {
            return "gameplay.threat.elevated"
        }

        return "gameplay.threat.low"
    }

    func start() {
        guard timerTask == nil else { return }

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    self?.tick()
                }
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    func handle(_ event: GameplaySceneEvent) {
        guard result == nil else { return }

        switch event {
        case .lootFound(let reward):
            inventory.append(reward)
            addScore(90 * momentumMultiplier + rarityBonus(for: reward.rarity))
            scorePulseKey = "gameplay.pulse.loot"
            if completeNextObjective() {
                addObjectiveScore()
            }
        case .objectiveCompleted:
            if completeNextObjective() {
                addObjectiveScore()
            }
        case .enemyContact(let enemy):
            enemyWarningKey = enemy.warningKey
            momentumMultiplier = 1
            addScore(-60)
            scorePulseKey = "gameplay.pulse.hit"
            health = max(0, health - 0.08)
            sanity = max(0, sanity - 0.14)
            if health <= 0 || sanity <= 0 {
                finish(success: false)
            }
        case .enemyWarning(let enemy):
            enemyWarningKey = enemy.warningKey
            addScore(25)
        case .extractionRequested:
            requestExtraction()
        case .roomEvent(let event):
            currentRoomEvent = event
            eventCounter += 1
            addScore(Int(event.intensity * 80))
            scorePulseKey = event.intensity > 0.6 ? "gameplay.pulse.anomaly" : nil
            sanity = max(0, sanity - event.intensity * 0.04)
        }
    }

    func requestExtraction() {
        guard result == nil else { return }
        extractionReady = true

        if allObjectivesComplete || collapseLevel > 0.72 {
            finish(success: allObjectivesComplete || collapseLevel < 0.95)
        } else {
            currentRoomEvent = NightmareEvent(
                id: "falseExit",
                titleKey: "event.falseExit.title",
                descriptionKey: "event.falseExit.description",
                intensity: 0.5
            )
            eventCounter += 1
            sanity = max(0, sanity - 0.08)
        }
    }

    private func tick() {
        guard result == nil else { return }

        tickCount += 1
        collapseLevel = min(1, collapseLevel + 0.013 * mission.difficulty.collapseMultiplier)

        if tickCount % 9 == 0 || Double.random(in: 0 ... 1) < collapseLevel * 0.08 {
            currentRoomEvent = roomEventGenerator.randomEvent(collapseLevel: collapseLevel)
            eventCounter += 1
        }

        if collapseLevel > 0.55 {
            sanity = max(0, sanity - 0.004 * mission.difficulty.collapseMultiplier)
        }

        if collapseLevel > 0.76, tickCount % 5 == 0 {
            addScore(15)
        }

        if collapseLevel >= 1 {
            finish(success: false)
        }
    }

    @discardableResult
    private func completeNextObjective() -> Bool {
        guard let index = objectives.firstIndex(where: { !$0.isCompleted }) else {
            extractionReady = true
            return false
        }

        objectives[index].isCompleted = true
        extractionReady = allObjectivesComplete
        return true
    }

    private func finish(success: Bool) {
        guard result == nil else { return }
        stop()

        let baseRewards = lootGenerator.extractionRewards(success: success, difficulty: mission.difficulty)
        let retainedLoot = success ? inventory + baseRewards : []
        let xp = success ? mission.rewardXP + completedObjectiveCount * 20 : 10
        let finalScore = finalRunScore(success: success, retainedLoot: retainedLoot)

        result = ExtractionSummary(
            missionTitleKey: mission.titleKey,
            success: success,
            xpAwarded: xp,
            loot: retainedLoot,
            loreKey: loreGenerator.loreReward(seed: mission.seed),
            messageKey: loreGenerator.extractionMessage(success: success, collapseLevel: collapseLevel),
            collapseLevel: collapseLevel,
            score: finalScore,
            rankKey: rankKey(for: finalScore, success: success),
            highlightKey: highlightKey(success: success),
            runCode: runCode(score: finalScore)
        )
    }

    private func addObjectiveScore() {
        addScore(260 * momentumMultiplier + mission.modifierScoreBonus)
        momentumMultiplier = min(momentumMultiplier + 1, 5)
        scorePulseKey = "gameplay.pulse.objective"
    }

    private func addScore(_ amount: Int) {
        runScore = max(0, runScore + amount)
    }

    private func rarityBonus(for rarity: Rarity) -> Int {
        switch rarity {
        case .common: return 15
        case .uncommon: return 35
        case .rare: return 70
        case .epic: return 130
        case .legendary: return 220
        case .corrupted: return 300
        }
    }

    private func finalRunScore(success: Bool, retainedLoot: [LootReward]) -> Int {
        let completionScore = completedObjectiveCount * 240
        let collapseDramaScore = Int(collapseLevel * 620)
        let difficultyScore = Int(mission.difficulty.collapseMultiplier * 260)
        let lootScore = retainedLoot.reduce(0) { total, reward in
            total + rarityBonus(for: reward.rarity) + reward.quantity * 8
        }
        let closeCallBonus = success && collapseLevel >= 0.82 ? 450 : 0
        let extractionBonus = success ? 900 : 90

        return max(0, runScore + completionScore + collapseDramaScore + difficultyScore + lootScore + closeCallBonus + extractionBonus)
    }

    private func rankKey(for score: Int, success: Bool) -> String {
        guard success else {
            return score >= 900 ? "result.rank.c" : "result.rank.d"
        }

        if score >= 3_200 {
            return "result.rank.s"
        }

        if score >= 2_450 {
            return "result.rank.a"
        }

        if score >= 1_700 {
            return "result.rank.b"
        }

        return "result.rank.c"
    }

    private func highlightKey(success: Bool) -> String {
        guard success else {
            return "result.highlight.lostSignal"
        }

        if collapseLevel >= 0.88 {
            return "result.highlight.needle"
        }

        if completedObjectiveCount == objectives.count && inventory.count >= 3 {
            return "result.highlight.artifactRush"
        }

        if momentumMultiplier >= 4 {
            return "result.highlight.cleanSweep"
        }

        return "result.highlight.extracted"
    }

    private func runCode(score: Int) -> String {
        let seed = abs(mission.seed % 10_000)
        let collapse = Int(collapseLevel * 100)
        return "NF-\(seed)-\(collapse)-\(score % 10_000)"
    }
}
