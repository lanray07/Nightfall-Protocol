import Foundation

struct NightmareNameGenerator {
    private let keys = [
        "nightmare.name.asylum",
        "nightmare.name.staticCathedral",
        "nightmare.name.coldArchive",
        "nightmare.name.redPlatform",
        "nightmare.name.glassWard",
        "nightmare.name.nullHarbor"
    ]

    func generate(seed: Int = Int.random(in: 0 ... 10_000)) -> String {
        keys[abs(seed) % keys.count]
    }
}

struct MissionLoreGenerator {
    private let briefingKeys = [
        "lore.briefing.01",
        "lore.briefing.02",
        "lore.briefing.03",
        "lore.briefing.04",
        "lore.briefing.05",
        "lore.briefing.06"
    ]

    private let extractionKeys = [
        "extraction.success.message",
        "extraction.partial.message",
        "extraction.failure.message"
    ]

    let internalPromptPlaceholder =
        "You are Nightfall Protocol, a cinematic horror mission generator. Create short, unsettling, atmospheric mission briefings, artifact lore, nightmare events, and enemy warnings. Keep text suitable for a teen audience. Avoid graphic gore, hate, sexual content, or real-world extremist themes."

    func briefing(seed: Int) -> String {
        briefingKeys[abs(seed) % briefingKeys.count]
    }

    func extractionMessage(success: Bool, collapseLevel: Double) -> String {
        if success && collapseLevel < 0.65 {
            return extractionKeys[0]
        }

        if success {
            return extractionKeys[1]
        }

        return extractionKeys[2]
    }

    func loreReward(seed: Int) -> String {
        "lore.artifact.0\(abs(seed) % 6 + 1)"
    }
}

struct ObjectiveGenerator {
    func generateObjectiveStates(for type: ObjectiveType) -> [ObjectiveState] {
        switch type {
        case .recoverMemoryFragment:
            return [
                ObjectiveState(titleKey: "objective.recoverMemory.title", detailKey: "objective.recoverMemory.detail"),
                ObjectiveState(titleKey: "objective.reachExtraction.title", detailKey: "objective.reachExtraction.detail")
            ]
        case .extractDreamArtifact:
            return [
                ObjectiveState(titleKey: "objective.collectArtifact.title", detailKey: "objective.collectArtifact.detail"),
                ObjectiveState(titleKey: "objective.secureCase.title", detailKey: "objective.secureCase.detail"),
                ObjectiveState(titleKey: "objective.reachExtraction.title", detailKey: "objective.reachExtraction.detail")
            ]
        case .sealNightmareRift:
            return [
                ObjectiveState(titleKey: "objective.stabilizeRift.title", detailKey: "objective.stabilizeRift.detail"),
                ObjectiveState(titleKey: "objective.survivePulse.title", detailKey: "objective.survivePulse.detail")
            ]
        case .rescueLostEcho:
            return [
                ObjectiveState(titleKey: "objective.scanEcho.title", detailKey: "objective.scanEcho.detail"),
                ObjectiveState(titleKey: "objective.rescueEcho.title", detailKey: "objective.rescueEcho.detail")
            ]
        case .surviveUntilExtraction:
            return [
                ObjectiveState(titleKey: "objective.survive.title", detailKey: "objective.survive.detail"),
                ObjectiveState(titleKey: "objective.reachExtraction.title", detailKey: "objective.reachExtraction.detail")
            ]
        case .investigateBlackSite:
            return [
                ObjectiveState(titleKey: "objective.investigateBlackSite.title", detailKey: "objective.investigateBlackSite.detail"),
                ObjectiveState(titleKey: "objective.recoverMemory.title", detailKey: "objective.recoverMemory.detail")
            ]
        }
    }

    func generateMissions(for mode: GameMode) -> [MissionPlan] {
        let difficulties: [Difficulty] = mode == .daily ? [.unknown, .high, .medium] : Difficulty.allCases
        let types = ObjectiveType.allCases.shuffled()
        let nameGenerator = NightmareNameGenerator()
        let loreGenerator = MissionLoreGenerator()

        return types.enumerated().map { index, type in
            let seed = Int.random(in: 1 ... 99_999)
            let difficulty = difficulties[index % difficulties.count]
            return MissionPlan(
                titleKey: type.titleKey,
                descriptionKey: type.descriptionKey,
                nightmareNameKey: nameGenerator.generate(seed: seed),
                briefingKey: loreGenerator.briefing(seed: seed),
                difficulty: difficulty,
                objectiveType: type,
                rewardXP: 110 + index * 35 + Int(difficulty.collapseMultiplier * 25),
                objectives: generateObjectiveStates(for: type),
                seed: seed
            )
        }
    }
}

struct RoomEventGenerator {
    private let events = [
        NightmareEvent(id: "lightsOut", titleKey: "event.lightsOut.title", descriptionKey: "event.lightsOut.description", intensity: 0.35),
        NightmareEvent(id: "falseExit", titleKey: "event.falseExit.title", descriptionKey: "event.falseExit.description", intensity: 0.5),
        NightmareEvent(id: "whisperWarning", titleKey: "event.whisperWarning.title", descriptionKey: "event.whisperWarning.description", intensity: 0.25),
        NightmareEvent(id: "entitySurge", titleKey: "event.entitySurge.title", descriptionKey: "event.entitySurge.description", intensity: 0.65),
        NightmareEvent(id: "gravityShift", titleKey: "event.gravityShift.title", descriptionKey: "event.gravityShift.description", intensity: 0.45),
        NightmareEvent(id: "mirrorClone", titleKey: "event.mirrorClone.title", descriptionKey: "event.mirrorClone.description", intensity: 0.55),
        NightmareEvent(id: "roomRearrangement", titleKey: "event.roomRearrangement.title", descriptionKey: "event.roomRearrangement.description", intensity: 0.6),
        NightmareEvent(id: "panicPulse", titleKey: "event.panicPulse.title", descriptionKey: "event.panicPulse.description", intensity: 0.7)
    ]

    func randomEvent(collapseLevel: Double) -> NightmareEvent {
        let weighted = events.filter { $0.intensity <= max(0.3, collapseLevel + 0.25) }
        return (weighted.isEmpty ? events : weighted).randomElement() ?? events[0]
    }
}

struct EnemySpawnDirector {
    func spawns(for difficulty: Difficulty) -> [EnemySpawnDefinition] {
        let base: [EnemySpawnDefinition] = [
            EnemySpawnDefinition(type: .watcher, normalizedStart: CGPoint(x: 0.25, y: 0.72), patrolBias: 0.35),
            EnemySpawnDefinition(type: .archivist, normalizedStart: CGPoint(x: 0.72, y: 0.62), patrolBias: 0.45),
            EnemySpawnDefinition(type: .sleeper, normalizedStart: CGPoint(x: 0.48, y: 0.34), patrolBias: 0.3)
        ]

        switch difficulty {
        case .low:
            return Array(base.prefix(2))
        case .medium:
            return base
        case .high:
            return base + [EnemySpawnDefinition(type: .echo, normalizedStart: CGPoint(x: 0.12, y: 0.22), patrolBias: 0.5)]
        case .extreme, .unknown:
            return base + [
                EnemySpawnDefinition(type: .echo, normalizedStart: CGPoint(x: 0.12, y: 0.22), patrolBias: 0.5),
                EnemySpawnDefinition(type: .hollow, normalizedStart: CGPoint(x: 0.88, y: 0.2), patrolBias: 0.65)
            ]
        }
    }
}

struct LootGenerator {
    func sceneLoot() -> LootReward {
        let table: [LootReward] = [
            LootReward(nameKey: "loot.dreamFragment.name", descriptionKey: "loot.dreamFragment.description", itemType: .dreamFragment, rarity: .uncommon, quantity: 1),
            LootReward(nameKey: "loot.corruptedKey.name", descriptionKey: "loot.corruptedKey.description", itemType: .corruptedKey, rarity: .rare, quantity: 1),
            LootReward(nameKey: "loot.protocolToken.name", descriptionKey: "loot.protocolToken.description", itemType: .protocolToken, rarity: .common, quantity: Int.random(in: 8 ... 18)),
            LootReward(nameKey: "loot.cosmeticShard.name", descriptionKey: "loot.cosmeticShard.description", itemType: .cosmeticShard, rarity: .epic, quantity: 1),
            LootReward(nameKey: "loot.loreFile.name", descriptionKey: "loot.loreFile.description", itemType: .loreFile, rarity: .rare, quantity: 1)
        ]

        return table.randomElement() ?? table[0]
    }

    func extractionRewards(success: Bool, difficulty: Difficulty) -> [LootReward] {
        guard success else { return [] }

        var rewards = [
            LootReward(nameKey: "loot.protocolToken.name", descriptionKey: "loot.protocolToken.description", itemType: .protocolToken, rarity: .common, quantity: 30),
            sceneLoot()
        ]

        if difficulty == .extreme || difficulty == .unknown || Bool.random() {
            rewards.append(LootReward(
                nameKey: "loot.artifact.name",
                descriptionKey: "loot.artifact.description",
                itemType: .artifact,
                rarity: difficulty == .unknown ? .corrupted : .legendary,
                quantity: 1
            ))
        }

        return rewards
    }
}
