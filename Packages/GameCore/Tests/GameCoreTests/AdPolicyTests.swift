import Testing
@testable import GameCore

@Suite struct AdPolicyTests {
    let policy = AdPolicy()
    let ready = AdPolicyState(sessionCount: 2, levelsSinceInterstitial: 3, lastInterstitialAt: nil)

    func context(levels: Int = 12, removeAds: Bool = false, daily: Bool = false, overlay: Bool = false, now: Double = 1_000) -> InterstitialContext {
        InterstitialContext(completedCampaignLevels: levels, hasRemoveAds: removeAds, cameFromDaily: daily, isOverlayPresented: overlay, now: now)
    }

    @Test func showsWhenEveryRuleAllows() {
        #expect(policy.shouldShowInterstitial(ready, context()))
    }

    @Test func neverRules() {
        #expect(!policy.shouldShowInterstitial(ready, context(removeAds: true)))
        #expect(!policy.shouldShowInterstitial(ready, context(daily: true)))
        #expect(!policy.shouldShowInterstitial(ready, context(overlay: true)))
        #expect(!policy.shouldShowInterstitial(ready, context(levels: 9)))
        var firstSession = ready
        firstSession.sessionCount = 1
        #expect(!policy.shouldShowInterstitial(firstSession, context()))
    }

    @Test func spacingByLevelsAndTime() {
        var state = ready
        state.recordInterstitialShown(at: 1_000)
        for _ in 0..<2 { state.recordCampaignLevelCompleted() }
        #expect(!policy.shouldShowInterstitial(state, context(now: 2_000)))
        state.recordCampaignLevelCompleted()
        #expect(!policy.shouldShowInterstitial(state, context(now: 1_179)))
        #expect(policy.shouldShowInterstitial(state, context(now: 1_180)))
    }

    @Test func rewardedIsCappedPerDayAndOldDaysAreDropped() {
        var state = AdPolicyState()
        let day = DayKey("2026-11-10")!
        for _ in 0..<HintEconomy.rewardedAdDailyCap {
            #expect(policy.canOfferRewarded(state, day: day))
            state.recordRewarded(day: day)
        }
        #expect(!policy.canOfferRewarded(state, day: day))
        #expect(policy.canOfferRewarded(state, day: day.adding(days: 1)))
        state.recordRewarded(day: day.adding(days: 8))
        #expect(state.rewardedByDay.keys.sorted() == ["2026-11-18"])
    }

    @Test func launchesAreCounted() {
        var state = AdPolicyState()
        state.recordLaunch()
        state.recordLaunch()
        #expect(state.sessionCount == 2)
    }
}
