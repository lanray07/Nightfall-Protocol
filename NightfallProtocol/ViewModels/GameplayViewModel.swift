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
            completeNextObjective()
        case .objectiveCompleted:
            completeNextObjective()
        case .enemyContact(let enemy):
            enemyWarningKey = enemy.warningKey
            health = max(0, health - 0.08)
            sanity = max(0, sanity - 0.14)
            if health <= 0 || sanity <= 0 {
                finish(success: false)
            }
        case .enemyWarning(let enemy):
            enemyWarningKey = enemy.warningKey
        case .extractionRequested:
            requestExtraction()
        case .roomEvent(let event):
            currentRoomEvent = event
            eventCounter += 1
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

        if collapseLevel >= 1 {
            finish(success: false)
        }
    }

    private func completeNextObjective() {
        guard let index = objectives.firstIndex(where: { !$0.isCompleted }) else {
            extractionReady = true
            return
        }

        objectives[index].isCompleted = true
        extractionReady = allObjectivesComplete
    }

    private func finish(success: Bool) {
        guard result == nil else { return }
        stop()

        let baseRewards = lootGenerator.extractionRewards(success: success, difficulty: mission.difficulty)
        let retainedLoot = success ? inventory + baseRewards : []
        let xp = success ? mission.rewardXP + completedObjectiveCount * 20 : 10

        result = ExtractionSummary(
            missionTitleKey: mission.titleKey,
            success: success,
            xpAwarded: xp,
            loot: retainedLoot,
            loreKey: loreGenerator.loreReward(seed: mission.seed),
            messageKey: loreGenerator.extractionMessage(success: success, collapseLevel: collapseLevel),
            collapseLevel: collapseLevel
        )
    }
}
