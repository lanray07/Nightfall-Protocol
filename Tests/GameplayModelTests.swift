import XCTest
@testable import NightfallProtocol

@MainActor
final class GameplayModelTests: XCTestCase {
    func testLootAndLateCollapseCannotBypassMission() {
        let mission = ObjectiveGenerator().generateMissions(for: .solo)[0]
        let model = GameplayViewModel(mission: mission)
        model.handle(.lootFound(LootReward(nameKey: "loot.artifact.name", descriptionKey: "loot.artifact.description", itemType: .artifact, rarity: .rare, quantity: 1)))
        XCTAssertEqual(model.completedObjectiveCount, 0)
        model.collapseLevel = 0.9
        model.requestExtraction()
        XCTAssertNil(model.result)
        XCTAssertFalse(model.extractionReady)
        model.handle(.missionProgress(2))
        XCTAssertEqual(model.completedObjectiveCount, 2)
        model.requestExtraction()
        XCTAssertEqual(model.result?.success, true)
        XCTAssertTrue(model.result?.loot.contains(where: { $0.itemType == .artifact }) == true)
    }

    func testContactFailureLosesCarriedLoot() {
        let mission = ObjectiveGenerator().generateMissions(for: .solo)[0]
        let model = GameplayViewModel(mission: mission)
        model.handle(.lootFound(LootReward(nameKey: "loot.artifact.name", descriptionKey: "loot.artifact.description", itemType: .artifact, rarity: .rare, quantity: 1)))
        model.health = 0.01
        model.handle(.enemyContact(.watcher))
        XCTAssertEqual(model.result?.success, false)
        XCTAssertTrue(model.result?.loot.isEmpty == true)
    }

    func testCampaignUnlocksAndDailyMissionContentIsStable() {
        let key = "nightfall.campaign.completed"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        UserDefaults.standard.removeObject(forKey: key)
        let generator = ObjectiveGenerator()
        XCTAssertEqual(generator.generateMissions(for: .story).count, 1)
        UserDefaults.standard.set(2, forKey: key)
        let chapters = generator.generateMissions(for: .story)
        XCTAssertEqual(chapters.map(\.campaignChapter), [0, 1, 2])
        XCTAssertEqual(Set(chapters.map(\.briefingKey)).count, 3)
        let daily1 = generator.generateMissions(for: .daily)
        let daily2 = generator.generateMissions(for: .daily)
        XCTAssertEqual(daily1.map(\.seed), daily2.map(\.seed))
        XCTAssertEqual(daily1.map(\.objectiveType), daily2.map(\.objectiveType))
        XCTAssertEqual(daily1.map(\.difficulty), daily2.map(\.difficulty))
    }
}
