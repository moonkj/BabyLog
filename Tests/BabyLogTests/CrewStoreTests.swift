// CrewStoreTests.swift
// BabyLogTests — 크루 로컬 백본

import XCTest
@testable import BabyLog

@MainActor
final class CrewStoreTests: XCTestCase {

    private func newStore() -> AppStore {
        let s = AppStore(); s.seedCrewIfNeeded(); return s
    }

    func test_seedsOnce() {
        let s = newStore()
        XCTAssertFalse(s.crews.isEmpty)
        let n = s.crews.count
        s.seedCrewIfNeeded()
        XCTAssertEqual(s.crews.count, n)
    }

    func test_createMeetup_autoJoinsHost() {
        let s = newStore()
        let m = CrewMeetup(place: "우리 동네 공원", when: "토 3시", hostName: "나",
                           hostTier: .new, joined: 0, capacity: 6, meetupType: .park, mine: true)
        s.addCrew(m)
        XCTAssertEqual(s.crews.first?.id, m.id)
        XCTAssertTrue(s.isJoinedCrew(m.id))   // 주최자 자동 참여
    }

    func test_joinTogglesCount() {
        let s = newStore()
        let m = s.crews[0]                      // 시드(내 모임 아님)
        let base = s.crewJoinedCount(m)
        s.toggleJoinCrew(m.id)
        XCTAssertEqual(s.crewJoinedCount(m), base + 1)
        s.toggleJoinCrew(m.id)
        XCTAssertEqual(s.crewJoinedCount(m), base)
    }
}
