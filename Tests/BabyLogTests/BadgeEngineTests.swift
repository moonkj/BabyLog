// BadgeEngineTests.swift
// BabyLogTests
//
// QA — BadgeEngine.earnedBadges(recordCount:consecutiveDays:tradeCount:crewMeetings:postLikes:)
//       계약 검증 (BadgeEngine.swift SPEC 7.3)
//
// ===== 코더와 어긋날 수 있는 지점 =====
//
// [1] 구현이 이미 존재하므로 계약 불일치 위험은 낮다. 단, 임계값이 스펙에서 변경될 경우
//     (예: streak_30 → streak_21, info_master likes 500 → 1000) 기존 테스트와 충돌.
//
// [2] "sharing_angel"과 "trade_50"은 동일한 tradeCount를 공유한다.
//     tradeCount >= 50이면 두 뱃지가 동시에 부여된다. 이 동시 부여가 의도된 설계인지
//     코더에게 확인 필요. 현재 구현은 동시 부여를 지원하며 테스트도 이를 검증한다.
//
// [3] 각 파라미터는 독립적으로 평가된다. 예: recordCount=0이어도 consecutiveDays >= 30이면
//     streak_30이 부여된다. (현재 구현 일치)
//
// [4] 음수 입력에 대한 방어 계약이 명세에 없다. 테스트는 0을 최솟값으로 가정한다.
//     코더가 precondition/assert를 추가하면 음수 테스트가 crash로 변환.

import XCTest
@testable import BabyLog

final class BadgeEngineTests: XCTestCase {

    // MARK: - 모두 0 → 빈 집합

    func test_allZero_returnsEmptySet() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0,
            consecutiveDays: 0,
            tradeCount: 0,
            crewMeetings: 0,
            postLikes: 0
        )
        XCTAssertTrue(badges.isEmpty,
            "모든 지표가 0이면 빈 집합을 반환해야 한다")
    }

    // MARK: - record_start (recordCount >= 1)

    func test_recordStart_threshold_0_notAwarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertFalse(badges.contains("record_start"),
            "recordCount=0이면 record_start 미부여")
    }

    func test_recordStart_threshold_1_awarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 1, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertTrue(badges.contains("record_start"),
            "recordCount=1이면 record_start 부여")
    }

    func test_recordStart_above_threshold_awarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 10, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertTrue(badges.contains("record_start"))
    }

    // MARK: - streak_30 (consecutiveDays >= 30)

    func test_streak30_threshold_29_notAwarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 29, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertFalse(badges.contains("streak_30"),
            "consecutiveDays=29이면 streak_30 미부여")
    }

    func test_streak30_threshold_30_awarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 30, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertTrue(badges.contains("streak_30"),
            "consecutiveDays=30이면 streak_30 부여")
    }

    func test_streak30_above_threshold_awarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 100, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertTrue(badges.contains("streak_30"))
    }

    /// streak_30은 recordCount와 독립 [주의 §3]
    func test_streak30_independentOf_recordCount() {
        let badgesWithNoRecords = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 30, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertTrue(badgesWithNoRecords.contains("streak_30"),
            "recordCount=0이어도 consecutiveDays>=30이면 streak_30 부여")
    }

    // MARK: - parenting_pro (recordCount >= 50)

    func test_parentingMaster_threshold_49_notAwarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 49, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertFalse(badges.contains("parenting_pro"),
            "recordCount=49이면 parenting_pro 미부여")
    }

    func test_parentingMaster_threshold_50_awarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 50, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertTrue(badges.contains("parenting_pro"),
            "recordCount=50이면 parenting_pro 부여")
    }

    /// record_start + parenting_pro 동시 부여 (recordCount=50)
    func test_parentingMaster_also_awardsRecordStart() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 50, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertTrue(badges.contains("record_start"),
            "recordCount=50이면 record_start(>=1)도 동시 부여")
        XCTAssertTrue(badges.contains("parenting_pro"))
    }

    // MARK: - sharing_angel (tradeCount >= 3)

    func test_sharingAngel_threshold_2_notAwarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 2,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertFalse(badges.contains("sharing_angel"),
            "tradeCount=2이면 sharing_angel 미부여")
    }

    func test_sharingAngel_threshold_3_awarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 3,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertTrue(badges.contains("sharing_angel"),
            "tradeCount=3이면 sharing_angel 부여")
    }

    // MARK: - trade_50 (tradeCount >= 50)

    func test_trade50_threshold_49_notAwarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 49,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertFalse(badges.contains("trade_50"),
            "tradeCount=49이면 trade_50 미부여")
    }

    func test_trade50_threshold_50_awarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 50,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertTrue(badges.contains("trade_50"),
            "tradeCount=50이면 trade_50 부여")
    }

    /// trade_50이면 sharing_angel도 동시 부여 [주의 §2]
    func test_trade50_also_awardsSharingAngel() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 50,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertTrue(badges.contains("sharing_angel"),
            "tradeCount=50이면 sharing_angel(>=3)도 동시 부여 [주의: 의도된 설계 여부 확인]")
        XCTAssertTrue(badges.contains("trade_50"))
    }

    // MARK: - first_crew (crewMeetings >= 1)

    func test_firstCrew_threshold_0_notAwarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertFalse(badges.contains("first_crew"),
            "crewMeetings=0이면 first_crew 미부여")
    }

    func test_firstCrew_threshold_1_awarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 1, postLikes: 0
        )
        XCTAssertTrue(badges.contains("first_crew"),
            "crewMeetings=1이면 first_crew 부여")
    }

    // MARK: - info_master (postLikes >= 500)

    func test_infoMaster_threshold_499_notAwarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 0, postLikes: 499
        )
        XCTAssertFalse(badges.contains("info_master"),
            "postLikes=499이면 info_master 미부여")
    }

    func test_infoMaster_threshold_500_awarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 0, postLikes: 500
        )
        XCTAssertTrue(badges.contains("info_master"),
            "postLikes=500이면 info_master 부여")
    }

    func test_infoMaster_above_threshold_awarded() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 0, postLikes: 1000
        )
        XCTAssertTrue(badges.contains("info_master"))
    }

    // MARK: - 전체 조건 동시 만족 → 7개 뱃지 전부

    func test_allThresholdsMet_returnsAllSevenBadges() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 50,
            consecutiveDays: 30,
            tradeCount: 50,
            crewMeetings: 1,
            postLikes: 500
        )

        let expected: Set<String> = [
            "record_start",
            "streak_30",
            "parenting_pro",
            "sharing_angel",
            "trade_50",
            "first_crew",
            "info_master"
        ]
        XCTAssertEqual(badges, expected,
            "모든 임계값 충족 시 7개 뱃지 전부를 반환해야 한다")
    }

    // MARK: - 반환 타입은 Set이므로 중복 없음 보장

    func test_earnedBadges_returnsUniqueKeys() {
        // BadgeEngine을 100회 호출해도 동일 결과 (결정적)
        let a = BadgeEngine.earnedBadges(
            recordCount: 5, consecutiveDays: 5,
            tradeCount: 5, crewMeetings: 2, postLikes: 5
        )
        let b = BadgeEngine.earnedBadges(
            recordCount: 5, consecutiveDays: 5,
            tradeCount: 5, crewMeetings: 2, postLikes: 5
        )
        XCTAssertEqual(a, b, "동일한 입력에 대해 항상 같은 Set을 반환해야 한다 (순수 함수)")
    }

    // MARK: - 각 뱃지 키 독립 평가 검증 (단일 조건만 충족)

    func test_onlyRecordStart_noOtherBadges() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 1, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 0, postLikes: 0
        )
        XCTAssertEqual(badges, ["record_start"],
            "recordCount=1만 충족 시 record_start 하나만 부여")
    }

    func test_onlyFirstCrew_noOtherBadges() {
        let badges = BadgeEngine.earnedBadges(
            recordCount: 0, consecutiveDays: 0, tradeCount: 0,
            crewMeetings: 1, postLikes: 0
        )
        XCTAssertEqual(badges, ["first_crew"],
            "crewMeetings=1만 충족 시 first_crew 하나만 부여")
    }
}
