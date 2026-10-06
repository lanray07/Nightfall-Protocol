import Foundation
import QuartzCore
import SpriteKit
import UIKit

@MainActor
final class NightfallGameScene: SKScene {
    var onEvent: (@MainActor (GameplaySceneEvent) -> Void)?
    var collapseProvider: (@MainActor () -> Double)?
    private var premiumEnabled = false
    private var lastCosmeticTrailTime: TimeInterval = 0

    static var monthlyCosmeticColor: SKColor {
        let colors: [SKColor] = [.systemPink, .systemMint, .systemOrange, .systemYellow]
        let month = Calendar(identifier: .gregorian).component(.month, from: Date())
        return colors[(month - 1) % colors.count]
    }

    private var mission: MissionPlan?
    private var rules = MissionRules(kind: .recoverMemoryFragment)
    private var condition: NightmareCondition = .blackout
    private var stations: [SKShapeNode] = []
    private var rescuedEcho: SKShapeNode?
    private var falseExits: [SKShapeNode] = []
    private var lastProgress = -1
    private var lastInstruction = ""
    private var runFinished = false
    private var darknessMask: SKShapeNode?
    private var channelRing: SKShapeNode?

    private var arena: CGRect {
        CGRect(x: 24, y: 210, width: max(120, size.width - 48), height: max(160, size.height - 500))
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: arena.minX + arena.width * x, y: arena.minY + arena.height * y)
    }
    private let player = SKShapeNode(circleOfRadius: 17)
    private let extractionZone = SKShapeNode(circleOfRadius: 42)
    private let staticOverlay = SKShapeNode(rect: .zero)
    private var targetPosition: CGPoint?
    private var artifactNodes: [SKShapeNode] = []
    private var enemyAgents: [EnemyAgent] = []
    private var playerTrail: [CGPoint] = []
    private var lastUpdateTime: TimeInterval = 0
    private var lastEnemyContactTime: TimeInterval = 0
    private var lastWarningTime: TimeInterval = 0
    private var exitRelocationThreshold = 0.35
    private let lootGenerator = LootGenerator()

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.015, green: 0.018, blue: 0.03, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
    }

    func configure(
        mission: MissionPlan,
        premiumEnabled: Bool = false,
        onEvent: @escaping @MainActor (GameplaySceneEvent) -> Void,
        collapseProvider: @escaping @MainActor () -> Double
    ) {
        self.mission = mission
        self.rules = MissionRules(kind: MissionRules.Kind(rawValue: mission.objectiveType.rawValue)!)
        self.condition = NightmareCondition(titleKey: mission.modifierTitleKey)
        runFinished = false
        lastProgress = -1
        lastInstruction = ""
        self.premiumEnabled = premiumEnabled
        self.onEvent = onEvent
        self.collapseProvider = collapseProvider
        buildWorld()
    }

    override func didMove(to view: SKView) {
        if player.parent == nil { buildWorld() }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        // Resizing must not reset collected loot or mission progression.
        if player.parent == nil { buildWorld() }
    }

    func setPremiumEnabled(_ enabled: Bool) {
        premiumEnabled = enabled
        player.fillColor = enabled ? Self.monthlyCosmeticColor : SKColor(red: 0.3, green: 0.75, blue: 1.0, alpha: 1)
    }

    func performInteraction() {
        guard player.parent != nil, !runFinished else { return }

        if let index = stations.indices.first(where: { stations[$0].position.distance(to: player.position) < 48 }) {
            rules.interact(station: index)
            if rules.kind == .sealNightmareRift && rules.activated {
                enemyAgents.forEach { $0.surgeUntil = CACurrentMediaTime() + 8 }
            }
            publishMissionProgress()
            return
        }

        if let artifact = artifactNodes.first(where: { $0.position.distance(to: player.position) < 58 }) {
            artifact.removeFromParent()
            artifactNodes.removeAll { $0 == artifact }
            onEvent?(.lootFound(lootGenerator.sceneLoot()))
            return
        }

        if extractionZone.position.distance(to: player.position) < 72 {
            onEvent?(.extractionRequested)
            return
        }

        onEvent?(.missionInstruction("mission.play.approach"))
    }

    func performExtraction() {
        guard !runFinished else { return }
        if falseExits.contains(where: { $0.position.distance(to: player.position) < 54 }) {
            onEvent?(.roomEvent(NightmareEvent(id: "falseExit", titleKey: "event.falseExit.title", descriptionKey: "event.falseExit.description", intensity: 0.5)))
            return
        }
        guard extractionZone.position.distance(to: player.position) < 58 else {
            onEvent?(.missionInstruction("mission.play.findExit"))
            return
        }
        onEvent?(.extractionRequested)
    }

    func finishRun() {
        runFinished = true
        isPaused = true
    }

    func applyNightmareEvent(_ event: NightmareEvent) {
        switch event.id {
        case "lightsOut":
            staticOverlay.fillColor = SKColor.black.withAlphaComponent(0.42)
        case "falseExit", "roomRearrangement":
            relocateExit()
        case "entitySurge":
            enemyAgents.forEach { $0.surgeUntil = CACurrentMediaTime() + 4 }
        case "gravityShift":
            targetPosition = CGPoint(x: size.width - player.position.x, y: player.position.y)
        case "mirrorClone":
            spawnMirrorClone()
        case "panicPulse":
            pulse(node: player, color: .systemRed)
        default:
            pulse(node: extractionZone, color: .systemCyan)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateTarget(from: touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateTarget(from: touches)
    }

    override func update(_ currentTime: TimeInterval) {
        guard player.parent != nil, !runFinished else { return }

        let deltaTime = min(max(currentTime - lastUpdateTime, 0), 1 / 20)
        lastUpdateTime = currentTime

        movePlayer(deltaTime: deltaTime)
        if premiumEnabled, currentTime - lastCosmeticTrailTime > 0.09,
           let targetPosition, targetPosition.distance(to: player.position) > 4 {
            lastCosmeticTrailTime = currentTime
            let mote = SKShapeNode(circleOfRadius: 4)
            mote.fillColor = Self.monthlyCosmeticColor
            mote.strokeColor = .clear
            mote.position = player.position
            mote.zPosition = 0.5
            mote.glowWidth = 3
            addChild(mote)
            mote.run(.sequence([.group([.fadeOut(withDuration: 0.55), .scale(to: 0.1, duration: 0.55)]), .removeFromParent()]))
        }
        moveEnemies(deltaTime: deltaTime, currentTime: currentTime)
        updateMission(deltaTime: deltaTime)
        updateCollapseVisuals(currentTime: currentTime)
        trackPlayerPath()
    }

    private func buildWorld() {
        guard let mission else { return }

        removeAllChildren()
        artifactNodes = []
        enemyAgents = []
        stations = []
        falseExits = []
        rescuedEcho = nil
        darknessMask = nil
        channelRing = nil
        playerTrail = []
        lastUpdateTime = 0
        lastCosmeticTrailTime = 0
        exitRelocationThreshold = 0.35
        backgroundColor = SKColor(red: 0.015, green: 0.018, blue: 0.03, alpha: 1)

        drawGrid()
        drawRooms()
        buildPlayer()
        buildArtifacts()
        buildExtractionZone()
        buildEnemies(for: mission.difficulty)
        buildMissionStations()
        buildOverlay()
        publishMissionProgress()
    }

    private func drawGrid() {
        let grid = SKNode()
        grid.alpha = 0.18

        let step: CGFloat = 56
        var x: CGFloat = 0
        while x <= size.width {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            let line = SKShapeNode(path: path)
            line.strokeColor = SKColor(red: 0.2, green: 0.35, blue: 0.55, alpha: 1)
            line.lineWidth = 1
            grid.addChild(line)
            x += step
        }

        var y: CGFloat = 0
        while y <= size.height {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            let line = SKShapeNode(path: path)
            line.strokeColor = SKColor(red: 0.2, green: 0.35, blue: 0.55, alpha: 1)
            line.lineWidth = 1
            grid.addChild(line)
            y += step
        }

        addChild(grid)
    }

    private func drawRooms() {
        let panels = [CGRect(x: 0.04, y: 0.08, width: 0.35, height: 0.3),
                      CGRect(x: 0.52, y: 0.06, width: 0.4, height: 0.35),
                      CGRect(x: 0.08, y: 0.58, width: 0.35, height: 0.34),
                      CGRect(x: 0.58, y: 0.56, width: 0.34, height: 0.36)]
        let theme = abs((mission?.seed ?? 0) % 3)
        let colors: [SKColor] = [.systemCyan, .systemPurple, .systemOrange]
        for (index, panel) in panels.enumerated() {
            let origin = point(panel.minX, panel.minY)
            let rect = CGRect(x: origin.x, y: origin.y, width: panel.width * arena.width, height: panel.height * arena.height)
            let room = SKShapeNode(rect: rect, cornerRadius: 5)
            room.fillColor = colors[theme].withAlphaComponent(0.055)
            room.strokeColor = colors[theme].withAlphaComponent(0.32)
            room.lineWidth = 2
            addChild(room)
            // Floor markings and machinery belong to this game's signal-map visual style.
            for line in 0..<4 {
                let mark = SKShapeNode(rectOf: CGSize(width: rect.width * 0.7, height: 2))
                mark.position = CGPoint(x: rect.midX, y: rect.minY + 10 + CGFloat(line) * 8)
                mark.fillColor = colors[theme].withAlphaComponent(0.18)
                mark.strokeColor = .clear
                addChild(mark)
            }
            let machinery = SKShapeNode(rectOf: CGSize(width: 22, height: 32), cornerRadius: 3)
            machinery.position = CGPoint(x: rect.maxX - 20, y: rect.maxY - 25)
            machinery.fillColor = .black
            machinery.strokeColor = colors[theme].withAlphaComponent(0.5)
            addChild(machinery)
            let light = SKShapeNode(circleOfRadius: 3)
            light.position = CGPoint(x: 0, y: 8)
            light.fillColor = index.isMultiple(of: 2) ? .systemRed : .systemMint
            light.strokeColor = .clear
            light.glowWidth = 4
            machinery.addChild(light)
        }
        let perimeter = SKShapeNode(rect: arena, cornerRadius: 6)
        perimeter.strokeColor = colors[theme].withAlphaComponent(0.7)
        perimeter.lineWidth = 2
        perimeter.fillColor = .clear
        addChild(perimeter)
    }

    private func buildPlayer() {
        player.removeAllChildren()
        player.position = point(0.16, 0.18)
        player.fillColor = premiumEnabled ? Self.monthlyCosmeticColor : SKColor(red: 0.3, green: 0.75, blue: 1.0, alpha: 1)
        player.strokeColor = .white
        player.lineWidth = 2
        player.glowWidth = 5
        player.zPosition = 1
        player.name = "player"
        let visor = SKShapeNode(rectOf: CGSize(width: 24, height: 6), cornerRadius: 2)
        visor.position.y = 5
        visor.fillColor = .black
        visor.strokeColor = .systemCyan
        player.addChild(visor)
        let pack = SKShapeNode(rectOf: CGSize(width: 18, height: 9), cornerRadius: 2)
        pack.position.y = -15
        pack.fillColor = .darkGray
        pack.strokeColor = .white.withAlphaComponent(0.5)
        player.addChild(pack)
        addChild(player)
    }

    private func buildArtifacts() {
        let positions = [
            point(0.35, 0.72),
            point(0.72, 0.72),
            point(0.67, 0.28)
        ]

        for position in positions {
            let artifact = SKShapeNode(rectOf: CGSize(width: 24, height: 24), cornerRadius: 5)
            artifact.position = position
            artifact.fillColor = SKColor(red: 0.9, green: 0.12, blue: 0.2, alpha: 0.95)
            artifact.strokeColor = SKColor(red: 1, green: 0.78, blue: 0.42, alpha: 0.9)
            artifact.glowWidth = 8
            artifact.zRotation = .pi / 4
            artifact.name = "artifact"
            addChild(artifact)
            artifactNodes.append(artifact)
        }
    }

    private func buildMissionStations() {
        let layouts: [[CGPoint]] = [
            [point(0.2, 0.7), point(0.75, 0.3), point(0.8, 0.7)],
            [point(0.7, 0.65), point(0.2, 0.4), point(0.75, 0.25)],
            [point(0.2, 0.5), point(0.7, 0.7), point(0.7, 0.25)]
        ]
        let positions = layouts[abs((mission?.seed ?? 0) % layouts.count)]
        for (index, position) in positions.enumerated() {
            let station = SKShapeNode(rectOf: CGSize(width: 38, height: 38), cornerRadius: 7)
            station.position = position
            station.fillColor = SKColor(red: 0.02, green: 0.1, blue: 0.13, alpha: 1)
            station.strokeColor = [.systemCyan, .systemOrange, .systemPurple][index]
            station.lineWidth = 3
            station.glowWidth = 3
            station.zPosition = 5
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = String(index + 1)
            label.fontSize = 18
            label.verticalAlignmentMode = .center
            station.addChild(label)
            addChild(station)
            stations.append(station)
        }
        let ring = SKShapeNode(circleOfRadius: 28)
        ring.strokeColor = .systemYellow
        ring.lineWidth = 3
        ring.zPosition = 6
        ring.isHidden = true
        addChild(ring)
        channelRing = ring

        if rules.kind == .rescueLostEcho {
            let echo = SKShapeNode(ellipseOf: CGSize(width: 20, height: 30))
            echo.fillColor = .systemMint
            echo.strokeColor = .white
            echo.glowWidth = 8
            echo.position = positions[0]
            echo.zPosition = 6
            addChild(echo)
            rescuedEcho = echo
        }
        if condition == .redSignal {
            for position in [point(0.1, 0.85), point(0.8, 0.15)] {
                let decoy = SKShapeNode(circleOfRadius: 30)
                decoy.position = position
                decoy.strokeColor = .systemRed
                decoy.lineWidth = 3
                decoy.glowWidth = 8
                addChild(decoy)
                falseExits.append(decoy)
            }
        }
    }

    private func updateMission(deltaTime: TimeInterval) {
        if let echo = rescuedEcho, rules.completed == 1 {
            let distance = echo.position.distance(to: player.position)
            // The echo waits if the operator runs too far away.
            if distance > 22 && distance < 150 {
                let step = min(CGFloat(deltaTime) * 105, distance - 22)
                echo.position.x += (player.position.x - echo.position.x) / distance * step
                echo.position.y += (player.position.y - echo.position.y) / distance * step
            }
        }
        rules.tick(seconds: deltaTime,
                   atChannelStation: stations.count > 1 && stations[1].position.distance(to: player.position) < 48,
                   echoAtExit: rescuedEcho.map { $0.position.distance(to: extractionZone.position) < 58 } ?? false)
        if let ring = channelRing, stations.count > 1 {
            ring.position = stations[1].position
            ring.isHidden = !rules.activated
            ring.setScale(1 + CGFloat(rules.channel) * 0.035)
        }
        for (index, station) in stations.enumerated() {
            let active: Bool
            switch rules.kind {
            case .investigateBlackSite:
                active = rules.completed == 0 ? index < 2 && !rules.scanned.contains(index) : index == 2
            case .surviveUntilExtraction: active = rules.completed == 1 && index == 0
            case .rescueLostEcho: active = rules.completed == 0 && index == 0
            default: active = index == rules.completed
            }
            station.alpha = active && !rules.ready ? 1 : 0.25
        }
        publishMissionProgress()
    }

    private func publishMissionProgress() {
        if lastProgress != rules.completed {
            lastProgress = rules.completed
            onEvent?(.missionProgress(rules.completed))
        }
        if lastInstruction != rules.instructionKey {
            lastInstruction = rules.instructionKey
            onEvent?(.missionInstruction(rules.instructionKey))
        }
    }

    private func buildExtractionZone() {
        extractionZone.position = point(0.86, 0.82)
        extractionZone.fillColor = SKColor(red: 0.05, green: 0.5, blue: 0.8, alpha: 0.18)
        extractionZone.strokeColor = SKColor(red: 0.3, green: 0.85, blue: 1, alpha: 0.95)
        extractionZone.lineWidth = 3
        extractionZone.glowWidth = 10
        addChild(extractionZone)
    }

    private func buildEnemies(for difficulty: Difficulty) {
        let director = EnemySpawnDirector()
        var spawns = director.spawns(for: difficulty)
        if condition == .hunted && !spawns.contains(where: { $0.type == .hollow }) {
            spawns.append(EnemySpawnDefinition(type: .hollow, normalizedStart: CGPoint(x: 0.8, y: 0.6), patrolBias: 0.3))
        }
        if condition == .echoTrail && !spawns.contains(where: { $0.type == .echo }) {
            spawns.append(EnemySpawnDefinition(type: .echo, normalizedStart: CGPoint(x: 0.6, y: 0.7), patrolBias: 0.3))
        }

        for spawn in spawns {
            let node = SKShapeNode(circleOfRadius: spawn.type == .sleeper ? 14 : 18)
            node.position = point(spawn.normalizedStart.x, spawn.normalizedStart.y)
            node.fillColor = color(for: spawn.type)
            node.strokeColor = .white.withAlphaComponent(spawn.type == .sleeper ? 0.2 : 0.55)
            node.lineWidth = 1
            node.alpha = spawn.type == .sleeper ? 0.28 : 0.9
            node.glowWidth = spawn.type == .hollow ? 8 : 4
            let eye = SKShapeNode(rectOf: CGSize(width: 20, height: 4), cornerRadius: 1)
            eye.fillColor = .white
            eye.strokeColor = .clear
            node.addChild(eye)
            if spawn.type == .hollow {
                node.yScale = 1.4
            } else if spawn.type == .echo {
                node.xScale = 0.7
            }
            addChild(node)

            let patrol = [
                node.position,
                CGPoint(x: max(arena.minX, min(arena.maxX, node.position.x + arena.width * spawn.patrolBias)), y: node.position.y),
                CGPoint(x: node.position.x, y: max(arena.minY, min(arena.maxY, node.position.y - arena.height * spawn.patrolBias)))
            ]
            enemyAgents.append(EnemyAgent(type: spawn.type, node: node, patrolPoints: patrol))
        }
    }

    private func buildOverlay() {
        staticOverlay.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        staticOverlay.fillColor = SKColor.black.withAlphaComponent(0.02)
        staticOverlay.strokeColor = .clear
        staticOverlay.zPosition = 100
        addChild(staticOverlay)
        if condition == .blackout {
            let mask = SKShapeNode()
            mask.fillColor = .black.withAlphaComponent(0.86)
            mask.strokeColor = .clear
            mask.zPosition = 99
            addChild(mask)
            darknessMask = mask
        }
    }

    private func color(for enemy: EnemyType) -> SKColor {
        switch enemy {
        case .watcher: return SKColor(red: 0.85, green: 0.15, blue: 0.22, alpha: 1)
        case .echo: return SKColor(red: 0.55, green: 0.55, blue: 0.95, alpha: 1)
        case .hollow: return SKColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        case .archivist: return SKColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1)
        case .sleeper: return SKColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 0.5)
        }
    }

    private func updateTarget(from touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        targetPosition = touch.location(in: self)
    }

    private func movePlayer(deltaTime: TimeInterval) {
        guard let targetPosition else { return }

        let vector = CGVector(dx: targetPosition.x - player.position.x, dy: targetPosition.y - player.position.y)
        let distance = hypot(vector.dx, vector.dy)
        guard distance > 4 else { return }

        let carryingCase = rules.kind == .extractDreamArtifact && rules.completed == 1
        let speed: CGFloat = carryingCase ? 125 : 178
        let step = min(CGFloat(deltaTime) * speed, distance)
        player.position.x += vector.dx / distance * step
        player.position.y += vector.dy / distance * step
        player.position.x = max(arena.minX, min(arena.maxX, player.position.x))
        player.position.y = max(arena.minY, min(arena.maxY, player.position.y))
    }

    private func moveEnemies(deltaTime: TimeInterval, currentTime: TimeInterval) {
        let collapse = collapseProvider?() ?? 0

        for agent in enemyAgents {
            let speedBoost = CGFloat(1 + collapse * 1.45)
            let surgeBoost: CGFloat = currentTime < agent.surgeUntil ? 1.75 : 1
            let speed = agent.type.baseSpeed * speedBoost * surgeBoost

            let destination: CGPoint
            if agent.type == .echo, let echoTarget = playerTrail.dropLast(condition.echoDelay).last {
                destination = echoTarget
            } else if agent.type == .hollow, collapse > condition.pursuitThreshold {
                destination = player.position
            } else {
                destination = agent.currentPatrolPoint
            }

            let vector = CGVector(dx: destination.x - agent.node.position.x, dy: destination.y - agent.node.position.y)
            let distance = hypot(vector.dx, vector.dy)

            if distance < 8 {
                agent.advancePatrol()
            } else {
                let step = min(CGFloat(deltaTime) * speed, distance)
                agent.node.position.x += vector.dx / distance * step
                agent.node.position.y += vector.dy / distance * step
            }

            evaluateDetection(for: agent, currentTime: currentTime, collapse: collapse)
        }
    }

    private func evaluateDetection(for agent: EnemyAgent, currentTime: TimeInterval, collapse: Double) {
        let distance = agent.node.position.distance(to: player.position)
        let detection = agent.type.detectionRadius * CGFloat(1 + collapse * 0.4)

        if distance < detection, currentTime - lastWarningTime > 2.0 {
            lastWarningTime = currentTime
            onEvent?(.enemyWarning(agent.type))
        }

        if distance < 28, currentTime - lastEnemyContactTime > 1.1 {
            rules.interrupt()
            lastEnemyContactTime = currentTime
            pulse(node: agent.node, color: .systemRed)
            onEvent?(.enemyContact(agent.type))
        }
    }

    private func updateCollapseVisuals(currentTime: TimeInterval) {
        let collapse = collapseProvider?() ?? 0

        if collapse > exitRelocationThreshold {
            exitRelocationThreshold += condition.exitInterval
            relocateExit()
        }

        let flicker = abs(sin(currentTime * (5 + collapse * 15))) * collapse
        staticOverlay.fillColor = SKColor(red: 0.12 + collapse * 0.35, green: 0.02, blue: 0.04, alpha: 0.04 + flicker * 0.18)
        extractionZone.alpha = 0.55 + abs(sin(currentTime * 3.2)) * 0.45
        if let mask = darknessMask {
            let path = CGMutablePath()
            path.addRect(arena)
            let radius: CGFloat = 95 - CGFloat(collapse) * 30
            // Reverse the aperture winding to cut a hole in the outer path.
            path.addPath(UIBezierPath(ovalIn: CGRect(x: player.position.x - radius, y: player.position.y - radius, width: radius * 2, height: radius * 2)).reversing().cgPath)
            mask.path = path
        }
    }

    private func trackPlayerPath() {
        playerTrail.append(player.position)

        if playerTrail.count > 140 {
            playerTrail.removeFirst(playerTrail.count - 140)
        }
    }

    private func relocateExit() {
        let positions = [
            point(0.84, 0.16),
            point(0.12, 0.82),
            point(0.82, 0.78),
            point(0.52, 0.12)
        ]

        let next = positions.randomElement() ?? positions[0]
        extractionZone.run(.sequence([
            .fadeAlpha(to: 0.1, duration: 0.18),
            .move(to: next, duration: 0.25),
            .fadeAlpha(to: 1, duration: 0.2)
        ]))
    }

    private func spawnMirrorClone() {
        let clone = SKShapeNode(circleOfRadius: 15)
        clone.position = CGPoint(x: size.width - player.position.x, y: player.position.y)
        clone.fillColor = SKColor(red: 0.62, green: 0.74, blue: 1, alpha: 0.45)
        clone.strokeColor = .white.withAlphaComponent(0.4)
        clone.glowWidth = 5
        addChild(clone)

        clone.run(.sequence([
            .group([.fadeOut(withDuration: 3), .scale(to: 1.8, duration: 3)]),
            .removeFromParent()
        ]))
    }

    private func pulse(node: SKNode, color: SKColor) {
        let pulse = SKShapeNode(circleOfRadius: 42)
        pulse.position = node.position
        pulse.strokeColor = color
        pulse.lineWidth = 3
        pulse.alpha = 0.9
        pulse.zPosition = 80
        addChild(pulse)
        pulse.run(.sequence([
            .group([.scale(to: 2.1, duration: 0.45), .fadeOut(withDuration: 0.45)]),
            .removeFromParent()
        ]))
    }
}

private final class EnemyAgent {
    let type: EnemyType
    let node: SKShapeNode
    let patrolPoints: [CGPoint]
    var patrolIndex = 0
    var surgeUntil: TimeInterval = 0

    init(type: EnemyType, node: SKShapeNode, patrolPoints: [CGPoint]) {
        self.type = type
        self.node = node
        self.patrolPoints = patrolPoints
    }

    var currentPatrolPoint: CGPoint {
        patrolPoints[patrolIndex % patrolPoints.count]
    }

    func advancePatrol() {
        patrolIndex = (patrolIndex + 1) % patrolPoints.count
    }
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        hypot(x - point.x, y - point.y)
    }
}
