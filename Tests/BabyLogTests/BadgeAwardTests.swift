// BadgeAwardTests.swift
// BabyLogTests — 마일스톤 뱃지 획득 감지

import XCTest
@testable import BabyLog

@MainActor
final class BadgeAwardTests: XCTestCase {

    func test_firstChildBadge_earnedAfterRegistering() {
        let store = AppStore()
        XCTAssertFalse(store.currentEarnedBadgeIds.contains("first_child"))
        store.completeBabyOnboarding(name: "지호", birthDate: Date(), gender: nil)
        XCTAssertTrue(store.currentEarnedBadgeIds.contains("first_child"))
    }

    func test_multiChildBadge_requiresTwo() {
        let store = AppStore()
        store.completeBabyOnboarding(name: "첫째", birthDate: Date(), gender: nil)
        XCTAssertFalse(store.currentEarnedBadgeIds.contains("multi_child"))
        store.completeBabyOnboarding(name: "둘째", birthDate: Date(), gender: nil)
        XCTAssertTrue(store.currentEarnedBadgeIds.contains("multi_child"))
    }

    func test_pregnancyBadge_earnedAfterStart() {
        let store = AppStore()
        XCTAssertFalse(store.currentEarnedBadgeIds.contains("pregnancy_logged"))
        store.startPregnancy(lmp: nil, edd: Date(), nickname: "튼튼이")
        XCTAssertTrue(store.currentEarnedBadgeIds.contains("pregnancy_logged"))
    }
}
