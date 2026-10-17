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
    private var mapDecor: [SKNode] = []
    private var worldSize: CGSize?
    private var receiver = FieldReceiver()
    private var transmissionPoint: CGPoint?
    private var traceMarker: SKNode?
    private var lastReceiverReadout = ""
    private var lastTraceTime: TimeInterval = 0
    private var hasDeparted = false

    private var arena: CGRect {
        arena(for: size)
    }

    private func arena(for dimensions: CGSize) -> CGRect {
        CGRect(x: 24, y: 24, width: max(1, dimensions.width - 48), height: max(1, dimensions.height - 48))
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
        guard player.parent != nil else { buildWorld(); return }
        // configure/didMove may already have built the world at the new size.
        // Remap from the dimensions actually used by the world, not the callback's old size.
        guard let worldSize, worldSize != size else { return }
        let previous = arena(for: worldSize)
        let next = arena
        func remap(_ location: CGPoint) -> CGPoint {
            let x = (location.x - previous.minX) / previous.width
            let y = (location.y - previous.minY) / previous.height
            return CGPoint(x: next.minX + x * next.width, y: next.minY + y * next.height)
        }
        // Preserve mission progress, loot and enemy state while keeping targets reachable.
        for node in [player, extractionZone] + artifactNodes + stations + falseExits {
            node.position = remap(node.position)
        }
        if let rescuedEcho { rescuedEcho.position = remap(rescuedEcho.position) }
        for agent in enemyAgents {
            agent.node.position = remap(agent.node.position)
            agent.patrolPoints = agent.patrolPoints.map(remap)
        }
        targetPosition = targetPosition.map(remap)
        playerTrail = playerTrail.map(remap)
        for node in children where node.name == "receiver-observation" || node.name == "receiver-wave" || node.name == "receiver-footstep" {
            node.position = remap(node.position)
        }
        transmissionPoint = transmissionPoint.map(remap)
        if let transmissionPoint { traceMarker?.position = transmissionPoint }
        staticOverlay.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        rebuildMapDecor()
        self.worldSize = size
    }

    func setPremiumEnabled(_ enabled: Bool) {
        premiumEnabled = enabled
        player.fillColor = enabled ? Self.monthlyCosmeticColor : SKColor(red: 0.3, green: 0.75, blue: 1.0, alpha: 1)
    }

    func soundReceiver() {
        guard !runFinished, !isPaused, receiver.sound() else { return }
        beginExpedition()
        transmissionPoint = player.position
        traceMarker?.removeFromParent()
        let marker = SKNode()
        marker.position = player.position
        marker.zPosition = 7
        for radius in [18, 26] {
            let ring = SKShapeNode(circleOfRadius: CGFloat(radius))
            ring.strokeColor = .systemOrange
            ring.lineWidth = 1
            marker.addChild(ring)
        }
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "TX / \(receiver.transmissions)"
        label.fontSize = 10
        label.fontColor = .systemOrange
        label.position.y = -38
        marker.addChild(label)
        addChild(marker)
        traceMarker = marker
        let wave = SKShapeNode(circleOfRadius: 20)
        wave.name = "receiver-wave"
        wave.position = player.position
        wave.strokeColor = .systemMint
        wave.lineWidth = 2
        wave.zPosition = 8
        addChild(wave)
        wave.run(.sequence([.group([.scale(to: 22, duration: 1.8), .fadeOut(withDuration: 1.8)]), .removeFromParent()]))
        // Last heard positions remain as hollow marks, not live enemy tracking.
        for agent in enemyAgents {
            let echo = SKShapeNode(circleOfRadius: 21)
            echo.name = "receiver-observation"
            echo.position = agent.node.position
            echo.strokeColor = .systemOrange.withAlphaComponent(0.6)
            echo.lineWidth = 1
            echo.zPosition = 0.7
            addChild(echo)
            echo.run(.sequence([.wait(forDuration: 4), .fadeOut(withDuration: 6), .removeFromParent()]))
        }
        publishReceiver()
    }

    func toggleSilentMovement() {
        guard !runFinished else { return }
        receiver.toggleSilent()
        publishReceiver()
    }

    private func beginExpedition() {
        guard !hasDeparted else { return }
        hasDeparted = true
        onEvent?(.expeditionStarted)
    }

    private func publishReceiver() {
        let signature = "\(Int(receiver.charge * 100)) / \(Int(ceil(receiver.traceRemaining))) / \(receiver.isSilent) / \(receiver.revealRemaining > 0)"
        guard signature != lastReceiverReadout else { return }
        lastReceiverReadout = signature
        onEvent?(.receiverChanged(receiver))
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
            // Keep the active task visible when extraction is attempted too early.
            onEvent?(.missionInstruction(rules.ready ? "mission.play.findExit" : rules.instructionKey))
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
        if hasDeparted { receiver.tick(seconds: deltaTime) }
        publishReceiver()
        if receiver.traceRemaining == 0 { traceMarker?.removeFromParent(); traceMarker = nil }
        for node in artifactNodes + enemyAgents.map(\.node) {
            node.alpha = receiver.revealRemaining > 0 || node.position.distance(to: player.position) < 105 ? 1 : 0
        }
        if currentTime - lastTraceTime > 0.3,
           let targetPosition, targetPosition.distance(to: player.position) > 5 {
            lastTraceTime = currentTime
            let trace = SKShapeNode(circleOfRadius: 1.6)
            trace.name = "receiver-footstep"
            trace.position = player.position
            trace.fillColor = .systemMint.withAlphaComponent(0.5)
            trace.strokeColor = .clear
            addChild(trace)
            trace.run(.sequence([.wait(forDuration: 8), .fadeOut(withDuration: 4), .removeFromParent()]))
        }
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
        if hasDeparted { moveEnemies(deltaTime: deltaTime, currentTime: currentTime) }
        updateMission(deltaTime: hasDeparted ? deltaTime : 0)
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
        receiver = FieldReceiver()
        transmissionPoint = nil
        traceMarker = nil
        lastReceiverReadout = ""
        lastTraceTime = 0
        hasDeparted = false
        targetPosition = nil
        exitRelocationThreshold = 0.35
        backgroundColor = SKColor(red: 0.015, green: 0.018, blue: 0.03, alpha: 1)

        mapDecor = []
        rebuildMapDecor()
        buildPlayer()
        buildArtifacts()
        buildExtractionZone()
        buildEnemies(for: mission.difficulty)
        buildMissionStations()
        buildOverlay()
        worldSize = size
        publishMissionProgress()
        publishReceiver()
    }

    private func drawGrid() {
        let plate = SKShapeNode(rect: arena.insetBy(dx: -7, dy: -7), cornerRadius: 2)
        plate.fillColor = SKColor(red: 0.07, green: 0.10, blue: 0.09, alpha: 1)
        plate.strokeColor = SKColor(red: 0.63, green: 0.53, blue: 0.36, alpha: 0.8)
        plate.zPosition = -3
        addChild(plate)
        // Seismic contours, not a universal grid: each mission has a different phase.
        let phase = CGFloat(abs((mission?.seed ?? 0) % 9))
        for index in 0..<17 {
            let path = CGMutablePath()
            for sample in 0...45 {
                let x = CGFloat(sample) / 45
                let y = (CGFloat(index) + 0.5) / 17 + sin(x * 9 + phase + CGFloat(index) * 0.38) * 0.026
                let location = point(x, max(0, min(1, y)))
                if sample == 0 { path.move(to: location) } else { path.addLine(to: location) }
            }
            let contour = SKShapeNode(path: path)
            contour.strokeColor = SKColor(red: 0.75, green: 0.77, blue: 0.57, alpha: 0.12)
            contour.lineWidth = 1
            contour.zPosition = -2
            addChild(contour)
        }
    }

    private func rebuildMapDecor() {
        mapDecor.forEach { $0.removeFromParent() }
        let existing = children
        drawGrid()
        drawRooms()
        mapDecor = children.filter { !existing.contains($0) }
    }

    private func drawRooms() {
        let panels = [CGRect(x: 0.04, y: 0.08, width: 0.35, height: 0.3),
                      CGRect(x: 0.52, y: 0.06, width: 0.4, height: 0.35),
                      CGRect(x: 0.08, y: 0.58, width: 0.35, height: 0.34),
                      CGRect(x: 0.58, y: 0.56, width: 0.34, height: 0.36)]
        let theme = abs((mission?.seed ?? 0) % 3)
        let colors: [SKColor] = [SKColor(red: 0.77, green: 0.85, blue: 0.57, alpha: 1),
                                 SKColor(red: 0.75, green: 0.63, blue: 0.44, alpha: 1), .systemMint]
        for (index, panel) in panels.enumerated() {
            let origin = point(panel.minX, panel.minY)
            let rect = CGRect(x: origin.x, y: origin.y, width: panel.width * arena.width, height: panel.height * arena.height)
            let shape = CGMutablePath()
            shape.move(to: CGPoint(x: rect.minX, y: rect.minY))
            shape.addLine(to: CGPoint(x: rect.maxX - 15, y: rect.minY))
            shape.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 15))
            shape.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            shape.addLine(to: CGPoint(x: rect.minX + 12, y: rect.maxY))
            shape.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 12))
            shape.closeSubpath()
            let room = SKShapeNode(path: shape)
            room.fillColor = colors[theme].withAlphaComponent(0.075)
            room.strokeColor = colors[theme].withAlphaComponent(0.45)
            room.lineWidth = 1
            addChild(room)
            let label = SKLabelNode(fontNamed: "Menlo")
            label.text = ["A / RECEIVING", "B / SPOOL", "C / NULL ROOM", "D / RETURN"][index]
            label.fontSize = min(10, rect.width / 12)
            label.fontColor = colors[theme].withAlphaComponent(0.65)
            label.position = CGPoint(x: rect.midX, y: rect.maxY - 14)
            addChild(label)
            // Floor markings and machinery belong to this game's signal-map visual style.
            for line in 0..<4 {
                let mark = SKShapeNode(rectOf: CGSize(width: rect.width * 0.7, height: 2))
                mark.position = CGPoint(x: rect.midX, y: rect.minY + 10 + CGFloat(line) * 8)
                mark.fillColor = colors[theme].withAlphaComponent(0.13)
                mark.strokeColor = .clear
                addChild(mark)
            }
            let machinery = SKShapeNode(circleOfRadius: index.isMultiple(of: 2) ? 15 : 10)
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
            for spindle in [-7, 7] {
                let reel = SKShapeNode(circleOfRadius: 5)
                reel.position.x = CGFloat(spindle)
                reel.strokeColor = colors[theme].withAlphaComponent(0.5)
                reel.lineWidth = 1
                machinery.addChild(reel)
            }
        }
        let perimeter = SKShapeNode(rect: arena, cornerRadius: 6)
        perimeter.strokeColor = colors[theme].withAlphaComponent(0.7)
        perimeter.lineWidth = 2
        perimeter.fillColor = .clear
        addChild(perimeter)
    }

    private func buildPlayer() {
        player.removeAllChildren()
        let silhouette = CGMutablePath()
        silhouette.move(to: CGPoint(x: 0, y: 19))
        for p in [CGPoint(x: 11, y: 4), CGPoint(x: 8, y: -13), CGPoint(x: 0, y: -7), CGPoint(x: -8, y: -13), CGPoint(x: -11, y: 4)] { silhouette.addLine(to: p) }
        silhouette.closeSubpath()
        player.path = silhouette
        player.position = point(0.16, 0.18)
        player.fillColor = premiumEnabled ? Self.monthlyCosmeticColor : SKColor(red: 0.3, green: 0.75, blue: 1.0, alpha: 1)
        player.strokeColor = .white
        player.lineWidth = 2
        player.glowWidth = 1
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
            let station = SKShapeNode(circleOfRadius: 21)
            station.position = position
            station.fillColor = SKColor(red: 0.02, green: 0.1, blue: 0.13, alpha: 1)
            station.strokeColor = [.systemMint, .systemOrange, .systemYellow][index]
            station.lineWidth = 2
            station.glowWidth = 1
            station.zPosition = 5
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = String(index + 1)
            label.fontSize = 18
            label.verticalAlignmentMode = .center
            station.addChild(label)
            for angle in [CGFloat(0), .pi / 2, .pi, .pi * 1.5] {
                let contact = SKShapeNode(rectOf: CGSize(width: 7, height: 4))
                contact.position = CGPoint(x: cos(angle) * 25, y: sin(angle) * 25)
                contact.zRotation = angle
                contact.fillColor = station.strokeColor
                contact.strokeColor = .clear
                station.addChild(contact)
            }
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
        extractionZone.removeAllChildren()
        extractionZone.position = point(0.86, 0.82)
        extractionZone.fillColor = SKColor(red: 0.05, green: 0.5, blue: 0.8, alpha: 0.18)
        extractionZone.strokeColor = SKColor(red: 0.3, green: 0.85, blue: 1, alpha: 0.95)
        extractionZone.lineWidth = 3
        extractionZone.glowWidth = 10
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "RETURN"
        label.fontSize = 10
        label.fontColor = .systemMint
        label.position.y = -5
        extractionZone.addChild(label)
        for index in 0..<3 {
            let tick = SKShapeNode(rectOf: CGSize(width: 3, height: 11))
            tick.fillColor = .systemMint
            tick.strokeColor = .clear
            tick.position.x = CGFloat(index - 1) * 8
            tick.position.y = 13
            extractionZone.addChild(tick)
        }
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
            let outline = CGMutablePath()
            outline.move(to: CGPoint(x: -16, y: -17))
            for p in [CGPoint(x: -11, y: 11), CGPoint(x: -5, y: 20), CGPoint(x: 0, y: 11), CGPoint(x: 7, y: 24), CGPoint(x: 14, y: 9), CGPoint(x: 17, y: -17), CGPoint(x: 5, y: -9), CGPoint(x: 0, y: -20), CGPoint(x: -7, y: -10)] { outline.addLine(to: p) }
            outline.closeSubpath()
            node.path = outline
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
        beginExpedition()
        let location = touch.location(in: self)
        targetPosition = CGPoint(x: max(arena.minX, min(arena.maxX, location.x)),
                                 y: max(arena.minY, min(arena.maxY, location.y)))
    }

    private func movePlayer(deltaTime: TimeInterval) {
        guard let targetPosition else { return }

        let vector = CGVector(dx: targetPosition.x - player.position.x, dy: targetPosition.y - player.position.y)
        let distance = hypot(vector.dx, vector.dy)
        guard distance > 4 else { return }

        player.zRotation = atan2(vector.dy, vector.dx) - .pi / 2

        let carryingCase = rules.kind == .extractDreamArtifact && rules.completed == 1
        let speed: CGFloat = (carryingCase ? 125 : 178) * CGFloat(receiver.movementScale)
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
            if receiver.traceRemaining > 0, let transmissionPoint {
                destination = transmissionPoint
            } else if agent.type == .echo, let echoTarget = playerTrail.dropLast(condition.echoDelay).last {
                destination = echoTarget
            } else if agent.type == .hollow, collapse > condition.pursuitThreshold,
                      !receiver.isSilent || receiver.canBeHeard(distance: Double(agent.node.position.distance(to: player.position)), detectionRadius: Double(agent.type.detectionRadius)) {
                destination = player.position
            } else if agent.type != .echo,
                      receiver.canBeHeard(distance: Double(agent.node.position.distance(to: player.position)), detectionRadius: Double(agent.type.detectionRadius) * (1 + collapse * 0.4)) {
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
        let detection = agent.type.detectionRadius * CGFloat(1 + collapse * 0.4) * CGFloat(receiver.detectionScale)

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
            let radius: CGFloat = receiver.revealRemaining > 0 ? max(arena.width, arena.height) : 95 - CGFloat(collapse) * 30
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
    var patrolPoints: [CGPoint]
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
