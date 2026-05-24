import QuartzCore
import SpriteKit

@MainActor
final class NightfallGameScene: SKScene {
    var onEvent: (@MainActor (GameplaySceneEvent) -> Void)?
    var collapseProvider: (@MainActor () -> Double)?

    private var mission: MissionPlan?
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
        onEvent: @escaping @MainActor (GameplaySceneEvent) -> Void,
        collapseProvider: @escaping @MainActor () -> Double
    ) {
        self.mission = mission
        self.onEvent = onEvent
        self.collapseProvider = collapseProvider
        buildWorld()
    }

    override func didMove(to view: SKView) {
        buildWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        buildWorld()
    }

    func performInteraction() {
        guard player.parent != nil else { return }

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

        let event = RoomEventGenerator().randomEvent(collapseLevel: collapseProvider?() ?? 0.2)
        onEvent?(.roomEvent(event))
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
        guard player.parent != nil else { return }

        let deltaTime = min(max(currentTime - lastUpdateTime, 0), 1 / 20)
        lastUpdateTime = currentTime

        movePlayer(deltaTime: deltaTime)
        moveEnemies(deltaTime: deltaTime, currentTime: currentTime)
        updateCollapseVisuals(currentTime: currentTime)
        trackPlayerPath()
    }

    private func buildWorld() {
        guard let mission else { return }

        removeAllChildren()
        artifactNodes = []
        enemyAgents = []
        playerTrail = []
        lastUpdateTime = 0
        exitRelocationThreshold = 0.35
        backgroundColor = SKColor(red: 0.015, green: 0.018, blue: 0.03, alpha: 1)

        drawGrid()
        drawRooms()
        buildPlayer()
        buildArtifacts()
        buildExtractionZone()
        buildEnemies(for: mission.difficulty)
        buildOverlay()
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
        let roomRects = [
            CGRect(x: size.width * 0.08, y: size.height * 0.12, width: size.width * 0.3, height: size.height * 0.25),
            CGRect(x: size.width * 0.5, y: size.height * 0.15, width: size.width * 0.34, height: size.height * 0.22),
            CGRect(x: size.width * 0.16, y: size.height * 0.58, width: size.width * 0.3, height: size.height * 0.25),
            CGRect(x: size.width * 0.58, y: size.height * 0.54, width: size.width * 0.28, height: size.height * 0.3)
        ]

        for rect in roomRects {
            let room = SKShapeNode(rect: rect, cornerRadius: 8)
            room.fillColor = SKColor(red: 0.03, green: 0.045, blue: 0.075, alpha: 0.78)
            room.strokeColor = SKColor(red: 0.35, green: 0.58, blue: 0.82, alpha: 0.28)
            room.lineWidth = 2
            addChild(room)
        }
    }

    private func buildPlayer() {
        player.position = CGPoint(x: size.width * 0.16, y: size.height * 0.18)
        player.fillColor = SKColor(red: 0.3, green: 0.75, blue: 1.0, alpha: 1)
        player.strokeColor = .white
        player.lineWidth = 2
        player.glowWidth = 5
        player.name = "player"
        addChild(player)
    }

    private func buildArtifacts() {
        let positions = [
            CGPoint(x: size.width * 0.35, y: size.height * 0.72),
            CGPoint(x: size.width * 0.72, y: size.height * 0.72),
            CGPoint(x: size.width * 0.67, y: size.height * 0.28)
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

    private func buildExtractionZone() {
        extractionZone.position = CGPoint(x: size.width * 0.86, y: size.height * 0.82)
        extractionZone.fillColor = SKColor(red: 0.05, green: 0.5, blue: 0.8, alpha: 0.18)
        extractionZone.strokeColor = SKColor(red: 0.3, green: 0.85, blue: 1, alpha: 0.95)
        extractionZone.lineWidth = 3
        extractionZone.glowWidth = 10
        addChild(extractionZone)
    }

    private func buildEnemies(for difficulty: Difficulty) {
        let director = EnemySpawnDirector()
        let spawns = director.spawns(for: difficulty)

        for spawn in spawns {
            let node = SKShapeNode(circleOfRadius: spawn.type == .sleeper ? 14 : 18)
            node.position = CGPoint(x: size.width * spawn.normalizedStart.x, y: size.height * spawn.normalizedStart.y)
            node.fillColor = color(for: spawn.type)
            node.strokeColor = .white.withAlphaComponent(spawn.type == .sleeper ? 0.2 : 0.55)
            node.lineWidth = 1
            node.alpha = spawn.type == .sleeper ? 0.28 : 0.9
            node.glowWidth = spawn.type == .hollow ? 8 : 4
            addChild(node)

            let patrol = [
                node.position,
                CGPoint(x: max(40, min(size.width - 40, node.position.x + size.width * spawn.patrolBias)), y: node.position.y),
                CGPoint(x: node.position.x, y: max(40, min(size.height - 40, node.position.y - size.height * spawn.patrolBias)))
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

        let speed: CGFloat = 178
        let step = min(CGFloat(deltaTime) * speed, distance)
        player.position.x += vector.dx / distance * step
        player.position.y += vector.dy / distance * step
        player.position.x = max(20, min(size.width - 20, player.position.x))
        player.position.y = max(20, min(size.height - 20, player.position.y))
    }

    private func moveEnemies(deltaTime: TimeInterval, currentTime: TimeInterval) {
        let collapse = collapseProvider?() ?? 0

        for agent in enemyAgents {
            let speedBoost = CGFloat(1 + collapse * 1.45)
            let surgeBoost: CGFloat = currentTime < agent.surgeUntil ? 1.75 : 1
            let speed = agent.type.baseSpeed * speedBoost * surgeBoost

            let destination: CGPoint
            if agent.type == .echo, let echoTarget = playerTrail.dropLast(25).last {
                destination = echoTarget
            } else if agent.type == .hollow, collapse > 0.58 {
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
            lastEnemyContactTime = currentTime
            pulse(node: agent.node, color: .systemRed)
            onEvent?(.enemyContact(agent.type))
        }
    }

    private func updateCollapseVisuals(currentTime: TimeInterval) {
        let collapse = collapseProvider?() ?? 0

        if collapse > exitRelocationThreshold {
            exitRelocationThreshold += 0.24
            relocateExit()
        }

        let flicker = abs(sin(currentTime * (5 + collapse * 15))) * collapse
        staticOverlay.fillColor = SKColor(red: 0.12 + collapse * 0.35, green: 0.02, blue: 0.04, alpha: 0.04 + flicker * 0.18)
        extractionZone.alpha = 0.55 + abs(sin(currentTime * 3.2)) * 0.45
    }

    private func trackPlayerPath() {
        playerTrail.append(player.position)

        if playerTrail.count > 140 {
            playerTrail.removeFirst(playerTrail.count - 140)
        }
    }

    private func relocateExit() {
        let positions = [
            CGPoint(x: size.width * 0.84, y: size.height * 0.16),
            CGPoint(x: size.width * 0.12, y: size.height * 0.82),
            CGPoint(x: size.width * 0.82, y: size.height * 0.78),
            CGPoint(x: size.width * 0.52, y: size.height * 0.12)
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
