import Foundation
import SwiftData
import SwiftUI

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case extreme
    case unknown

    var id: String { rawValue }

    var titleKey: String {
        "difficulty.\(rawValue)"
    }

    var tint: Color {
        switch self {
        case .low: .green
        case .medium: .yellow
        case .high: .orange
        case .extreme: .red
        case .unknown: .purple
        }
    }

    var collapseMultiplier: Double {
        switch self {
        case .low: 0.75
        case .medium: 1.0
        case .high: 1.3
        case .extreme: 1.65
        case .unknown: 1.95
        }
    }
}

enum ObjectiveType: String, Codable, CaseIterable, Identifiable {
    case recoverMemoryFragment
    case extractDreamArtifact
    case sealNightmareRift
    case rescueLostEcho
    case surviveUntilExtraction
    case investigateBlackSite

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .recoverMemoryFragment: "mission.recover.title"
        case .extractDreamArtifact: "mission.extract.title"
        case .sealNightmareRift: "mission.seal.title"
        case .rescueLostEcho: "mission.rescue.title"
        case .surviveUntilExtraction: "mission.survive.title"
        case .investigateBlackSite: "mission.investigate.title"
        }
    }

    var descriptionKey: String {
        switch self {
        case .recoverMemoryFragment: "mission.recover.description"
        case .extractDreamArtifact: "mission.extract.description"
        case .sealNightmareRift: "mission.seal.description"
        case .rescueLostEcho: "mission.rescue.description"
        case .surviveUntilExtraction: "mission.survive.description"
        case .investigateBlackSite: "mission.investigate.description"
        }
    }
}

enum ItemType: String, Codable, CaseIterable, Identifiable {
    case dreamFragment
    case corruptedKey
    case protocolToken
    case artifact
    case cosmeticShard
    case loreFile

    var id: String { rawValue }

    var titleKey: String {
        "itemType.\(rawValue)"
    }
}

enum Rarity: String, Codable, CaseIterable, Identifiable {
    case common
    case uncommon
    case rare
    case epic
    case legendary
    case corrupted

    var id: String { rawValue }

    var titleKey: String {
        "rarity.\(rawValue)"
    }

    var tint: Color {
        switch self {
        case .common: .gray
        case .uncommon: .green
        case .rare: .cyan
        case .epic: .purple
        case .legendary: .yellow
        case .corrupted: .red
        }
    }
}

enum EquipmentType: String, Codable, CaseIterable, Identifiable {
    case flashlight
    case signalScanner
    case decoyBeacon
    case silenceInjector
    case escapeFlare
    case artifactCase

    var id: String { rawValue }

    var nameKey: String {
        "equipment.\(rawValue).name"
    }

    var descriptionKey: String {
        "equipment.\(rawValue).description"
    }

    var symbolName: String {
        switch self {
        case .flashlight: "flashlight.on.fill"
        case .signalScanner: "dot.radiowaves.left.and.right"
        case .decoyBeacon: "antenna.radiowaves.left.and.right"
        case .silenceInjector: "syringe.fill"
        case .escapeFlare: "flame.fill"
        case .artifactCase: "shippingbox.fill"
        }
    }
}

enum EnemyType: String, Codable, CaseIterable, Identifiable {
    case watcher
    case echo
    case hollow
    case archivist
    case sleeper

    var id: String { rawValue }

    var nameKey: String {
        "enemy.\(rawValue).name"
    }

    var warningKey: String {
        "enemy.\(rawValue).warning"
    }

    var baseSpeed: CGFloat {
        switch self {
        case .watcher: 54
        case .echo: 68
        case .hollow: 92
        case .archivist: 46
        case .sleeper: 76
        }
    }

    var detectionRadius: CGFloat {
        switch self {
        case .watcher: 118
        case .echo: 88
        case .hollow: 78
        case .archivist: 104
        case .sleeper: 62
        }
    }
}

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case solo
    case coop
    case daily
    case endless
    case story

    var id: String { rawValue }

    var titleKey: String {
        "mode.\(rawValue)"
    }
}

enum GraphicsQuality: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var titleKey: String {
        "graphics.\(rawValue)"
    }
}

enum StoreCategory: String, Codable, CaseIterable, Identifiable {
    case cosmetic
    case pass
    case lore

    var id: String { rawValue }

    var titleKey: String {
        "store.category.\(rawValue)"
    }
}

struct LanguageOption: Identifiable, Hashable {
    let id: String
    let nameKey: String
    let localeIdentifier: String
    let isRightToLeft: Bool
}

struct ObjectiveState: Identifiable, Hashable, Codable {
    var id: UUID
    var titleKey: String
    var detailKey: String
    var isCompleted: Bool

    init(id: UUID = UUID(), titleKey: String, detailKey: String, isCompleted: Bool = false) {
        self.id = id
        self.titleKey = titleKey
        self.detailKey = detailKey
        self.isCompleted = isCompleted
    }
}

struct MissionPlan: Identifiable, Hashable, Codable {
    var id: UUID
    var titleKey: String
    var descriptionKey: String
    var nightmareNameKey: String
    var briefingKey: String
    var difficulty: Difficulty
    var objectiveType: ObjectiveType
    var rewardXP: Int
    var objectives: [ObjectiveState]
    var seed: Int

    init(
        id: UUID = UUID(),
        titleKey: String,
        descriptionKey: String,
        nightmareNameKey: String,
        briefingKey: String,
        difficulty: Difficulty,
        objectiveType: ObjectiveType,
        rewardXP: Int,
        objectives: [ObjectiveState],
        seed: Int
    ) {
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.nightmareNameKey = nightmareNameKey
        self.briefingKey = briefingKey
        self.difficulty = difficulty
        self.objectiveType = objectiveType
        self.rewardXP = rewardXP
        self.objectives = objectives
        self.seed = seed
    }
}

struct LootReward: Identifiable, Hashable, Codable {
    var id: UUID
    var nameKey: String
    var descriptionKey: String
    var itemType: ItemType
    var rarity: Rarity
    var quantity: Int

    init(
        id: UUID = UUID(),
        nameKey: String,
        descriptionKey: String,
        itemType: ItemType,
        rarity: Rarity,
        quantity: Int
    ) {
        self.id = id
        self.nameKey = nameKey
        self.descriptionKey = descriptionKey
        self.itemType = itemType
        self.rarity = rarity
        self.quantity = quantity
    }
}

struct ExtractionSummary: Identifiable, Hashable, Codable {
    var id: UUID
    var missionTitleKey: String
    var success: Bool
    var xpAwarded: Int
    var loot: [LootReward]
    var loreKey: String
    var messageKey: String
    var collapseLevel: Double

    init(
        id: UUID = UUID(),
        missionTitleKey: String,
        success: Bool,
        xpAwarded: Int,
        loot: [LootReward],
        loreKey: String,
        messageKey: String,
        collapseLevel: Double
    ) {
        self.id = id
        self.missionTitleKey = missionTitleKey
        self.success = success
        self.xpAwarded = xpAwarded
        self.loot = loot
        self.loreKey = loreKey
        self.messageKey = messageKey
        self.collapseLevel = collapseLevel
    }
}

struct StoreCatalogItem: Identifiable, Hashable {
    var id: String { productID }
    var productID: String
    var titleKey: String
    var descriptionKey: String
    var priceKey: String
    var category: StoreCategory
    var owned: Bool
}

struct LoadoutItem: Identifiable, Hashable {
    var id: EquipmentType { type }
    var type: EquipmentType
    var equipped: Bool
}

struct NightmareEvent: Identifiable, Hashable, Codable {
    var id: String
    var titleKey: String
    var descriptionKey: String
    var intensity: Double
}

struct EnemySpawnDefinition: Identifiable, Hashable {
    var id = UUID()
    var type: EnemyType
    var normalizedStart: CGPoint
    var patrolBias: CGFloat
}

enum GameplaySceneEvent {
    case lootFound(LootReward)
    case objectiveCompleted
    case enemyContact(EnemyType)
    case enemyWarning(EnemyType)
    case extractionRequested
    case roomEvent(NightmareEvent)
}

@Model
final class PlayerProfile {
    @Attribute(.unique) var id: UUID
    var username: String
    var level: Int
    var xp: Int
    var selectedLanguage: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        username: String = "operator",
        level: Int = 1,
        xp: Int = 0,
        selectedLanguage: String = "en",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.username = username
        self.level = level
        self.xp = xp
        self.selectedLanguage = selectedLanguage
        self.createdAt = createdAt
    }
}

@Model
final class Mission {
    @Attribute(.unique) var id: UUID
    var titleKey: String
    var descriptionKey: String
    var difficulty: String
    var objectiveType: String
    var rewardXP: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        titleKey: String,
        descriptionKey: String,
        difficulty: Difficulty,
        objectiveType: ObjectiveType,
        rewardXP: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.difficulty = difficulty.rawValue
        self.objectiveType = objectiveType.rawValue
        self.rewardXP = rewardXP
        self.createdAt = createdAt
    }
}

@Model
final class InventoryItem {
    @Attribute(.unique) var id: UUID
    var nameKey: String
    var descriptionKey: String
    var itemType: String
    var rarity: String
    var quantity: Int

    init(
        id: UUID = UUID(),
        nameKey: String,
        descriptionKey: String,
        itemType: ItemType,
        rarity: Rarity,
        quantity: Int
    ) {
        self.id = id
        self.nameKey = nameKey
        self.descriptionKey = descriptionKey
        self.itemType = itemType.rawValue
        self.rarity = rarity.rawValue
        self.quantity = quantity
    }
}

@Model
final class Artifact {
    @Attribute(.unique) var id: UUID
    var nameKey: String
    var descriptionKey: String
    var rarity: String
    var unlocked: Bool
    var nightmareOriginKey: String
    var gameplayBonusKey: String
    var loreKey: String

    init(
        id: UUID = UUID(),
        nameKey: String,
        descriptionKey: String,
        rarity: Rarity,
        unlocked: Bool,
        nightmareOriginKey: String,
        gameplayBonusKey: String,
        loreKey: String
    ) {
        self.id = id
        self.nameKey = nameKey
        self.descriptionKey = descriptionKey
        self.rarity = rarity.rawValue
        self.unlocked = unlocked
        self.nightmareOriginKey = nightmareOriginKey
        self.gameplayBonusKey = gameplayBonusKey
        self.loreKey = loreKey
    }
}

@Model
final class GameSession {
    @Attribute(.unique) var id: UUID
    var missionId: UUID
    var collapseLevel: Double
    var objectivesCompleted: Int
    var extractedSuccessfully: Bool
    var lootCollected: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        missionId: UUID,
        collapseLevel: Double,
        objectivesCompleted: Int,
        extractedSuccessfully: Bool,
        lootCollected: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.missionId = missionId
        self.collapseLevel = collapseLevel
        self.objectivesCompleted = objectivesCompleted
        self.extractedSuccessfully = extractedSuccessfully
        self.lootCollected = lootCollected
        self.createdAt = createdAt
    }
}

@Model
final class CosmeticItem {
    @Attribute(.unique) var id: UUID
    var nameKey: String
    var category: String
    var rarity: String
    var owned: Bool
    var equipped: Bool

    init(
        id: UUID = UUID(),
        nameKey: String,
        category: String,
        rarity: Rarity,
        owned: Bool,
        equipped: Bool
    ) {
        self.id = id
        self.nameKey = nameKey
        self.category = category
        self.rarity = rarity.rawValue
        self.owned = owned
        self.equipped = equipped
    }
}

@Model
final class PurchaseState {
    @Attribute(.unique) var id: UUID
    var productId: String
    var purchased: Bool
    var purchaseDate: Date?

    init(id: UUID = UUID(), productId: String, purchased: Bool, purchaseDate: Date?) {
        self.id = id
        self.productId = productId
        self.purchased = purchased
        self.purchaseDate = purchaseDate
    }
}
