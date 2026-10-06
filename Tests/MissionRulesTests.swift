import Foundation

@main
struct MissionRulesTests {
    static func main() {
        var memory = MissionRules(kind: .recoverMemoryFragment)
        memory.interact(station: 1)
        assert(memory.completed == 0, "Decoding before recovery must not advance")
        memory.interact(station: 0)
        memory.interact(station: 1)
        memory.tick(seconds: 2, atChannelStation: true, echoAtExit: false)
        assert(!memory.ready)
        memory.tick(seconds: 1, atChannelStation: true, echoAtExit: false)
        assert(memory.ready)

        for kind in [MissionRules.Kind.extractDreamArtifact, .sealNightmareRift] {
            var rules = MissionRules(kind: kind)
            rules.interact(station: 0)
            rules.interact(station: 1)
            rules.tick(seconds: 4, atChannelStation: true, echoAtExit: false)
            assert(!rules.ready)
            rules.interrupt()
            rules.tick(seconds: 10, atChannelStation: true, echoAtExit: false)
            assert(!rules.ready, "A hit must require reactivation")
            rules.interact(station: 1)
            rules.tick(seconds: 4, atChannelStation: true, echoAtExit: false)
            rules.tick(seconds: 1, atChannelStation: false, echoAtExit: false)
            assert(rules.channel == 0 && !rules.activated, "Leaving station resets channel")
            rules.interact(station: 1)
            rules.tick(seconds: 8, atChannelStation: true, echoAtExit: false)
            assert(rules.ready)
        }

        var echo = MissionRules(kind: .rescueLostEcho)
        echo.tick(seconds: 1, atChannelStation: false, echoAtExit: true)
        assert(!echo.ready, "An unawakened echo cannot be delivered")
        echo.interact(station: 0)
        echo.tick(seconds: 50, atChannelStation: false, echoAtExit: false)
        assert(!echo.ready, "Escort must reach exit")
        echo.tick(seconds: 1, atChannelStation: false, echoAtExit: true)
        assert(echo.ready)

        var survival = MissionRules(kind: .surviveUntilExtraction)
        survival.interact(station: 0)
        assert(survival.completed == 0)
        survival.tick(seconds: 29, atChannelStation: false, echoAtExit: false)
        assert(survival.completed == 0)
        survival.tick(seconds: 1, atChannelStation: false, echoAtExit: false)
        assert(survival.completed == 1 && !survival.ready)
        survival.interact(station: 0)
        assert(survival.ready)

        var archive = MissionRules(kind: .investigateBlackSite)
        archive.interact(station: 2)
        archive.interact(station: 0)
        archive.interact(station: 0)
        assert(archive.completed == 0, "Scanning one terminal repeatedly cannot replace the other")
        archive.interact(station: 1)
        assert(archive.completed == 1)
        archive.interact(station: 2)
        assert(archive.ready)
        archive.tick(seconds: 100, atChannelStation: false, echoAtExit: false)
        assert(archive.completed == 2)

        assert(NightmareCondition(titleKey: "modifier.zeroHour.title").collapseRate == 1.35)
        assert(NightmareCondition.glassMaze.exitInterval < NightmareCondition.blackout.exitInterval)
        assert(NightmareCondition.hunted.pursuitThreshold < NightmareCondition.blackout.pursuitThreshold)
        assert(NightmareCondition.echoTrail.echoDelay < NightmareCondition.blackout.echoDelay)
        print("Passed: six mission rule paths, invalid actions, timed channels, interruption, escort, survival and modifier configuration.")
    }
}
