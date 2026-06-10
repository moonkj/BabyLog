// TierCalculatorTests.swift
// BabyLogTests
//
// QA — TierCalculator 티어 계산 계약 검증 (경계값 분석)
//
// ─── 계약과 어긋날 수 있는 지점 ───────────────────────────────────────────────
//
// [1] Tier enum case명 — 계약은 sprout / warmNeighbor / trusted / golden.
//     SPEC.md(기능 7)의 한국어 이름(새싹/따뜻한이웃/믿음직한맘/골든맘)과
//     영문 case명이 다르다. 코더가 한국어 rawValue나 다른 영문명을 사용하면
//     컴파일 에러가 발생한다.
//
// [2] 티어 우선순위 평가 순서 — 계약상 golden 조건을 먼저 검사하고,
//     실패 시 trusted → warmNeighbor → sprout 순으로 폴백한다.
//     코더가 조건 검사 순서를 뒤집거나 병렬 평가하면 경계값 케이스가 오분류된다.
//     예: (30, 4.8, 5) — 거래·평점은 golden을 만족하지만 가입 부족으로
//     trusted에 해당해야 한다. 순서가 틀리면 sprout으로 떨어질 수 있다.
//
// [3] 조건 연산자 — 계약은 ">=" (이상). 코더가 ">" (초과)로 구현하면
//     경계값 (tradeCount=30, avgRating=4.8, joinedMonths=6) 케이스가
//     golden이 아닌 하위 티어로 내려간다.
//
// [4] trusted 조건에 joinedMonths 없음 — 스펙(기능 7 §따뜻한이웃 티어)은
//     "거래 10~29회 + 후기 평점 4.5 이상"으로 가입기간을 요구하지 않는다.
//     (10, 4.5, 0) → trusted 케이스가 이를 검증한다.
//
// [5] warmNeighbor 조건에 평점 없음 — 스펙은 "거래 3~9회"만 조건.
//     (3, 0, 0) → warmNeighbor 케이스가 평점 0이어도 승격됨을 검증한다.
//
// [6] TierCalculator 타입 형태 — 계약은 enum(케이스 없는 네임스페이스)이나
//     struct/class로 구현해도 static func이면 호출 방법은 동일하다.
//     단, 파라미터 레이블(tradeCount:avgRating:joinedMonths:)이 정확해야 한다.
//
// [7] avgRating 타입 — 계약은 Double. 코더가 Float을 쓰면 4.8 == 4.8 비교에서
//     부동소수점 오차가 발생할 수 있다.
//
// ─────────────────────────────────────────────────────────────────────────────

import XCTest
@testable import BabyLog

final class TierCalculatorTests: XCTestCase {

    // MARK: - golden 티어

    /// 모든 golden 조건 최솟값을 정확히 충족 → golden
    /// (tradeCount=30, avgRating=4.8, joinedMonths=6)
    func test_tier_allGoldenMinimum_returnsGolden() {
        let result = TierCalculator.tier(tradeCount: 30, avgRating: 4.8, joinedMonths: 6)
        XCTAssertEqual(result, .golden)
    }

    /// golden 조건을 한참 초과하는 값 → golden
    func test_tier_goldenHighValues_returnsGolden() {
        let result = TierCalculator.tier(tradeCount: 100, avgRating: 5.0, joinedMonths: 24)
        XCTAssertEqual(result, .golden)
    }

    // MARK: - golden 경계값 → trusted 폴백

    /// 거래·평점은 golden 이상이지만 joinedMonths=5(6 미만) → trusted
    /// 이 케이스는 조건 우선순위가 올바를 때만 trusted에 떨어진다.
    func test_tier_goldenTradeAndRatingButShortJoined_returnsTrusted() {
        let result = TierCalculator.tier(tradeCount: 30, avgRating: 4.8, joinedMonths: 5)
        XCTAssertEqual(result, .trusted)
    }

    /// 거래·가입은 golden 이상이지만 avgRating=4.7(4.8 미만) → trusted
    func test_tier_goldenTradeAndJoinedButLowRating_returnsTrusted() {
        let result = TierCalculator.tier(tradeCount: 30, avgRating: 4.7, joinedMonths: 6)
        XCTAssertEqual(result, .trusted)
    }

    // MARK: - trusted 티어

    /// trusted 최솟값: tradeCount=10, avgRating=4.5, joinedMonths는 무관(0) → trusted
    func test_tier_trustedMinimum_returnsTrusted() {
        let result = TierCalculator.tier(tradeCount: 10, avgRating: 4.5, joinedMonths: 0)
        XCTAssertEqual(result, .trusted)
    }

    /// tradeCount=29, avgRating=5.0 → golden 거래 조건(30) 미달이지만 trusted는 충족
    func test_tier_trade29RatingHigh_returnsTrusted() {
        let result = TierCalculator.tier(tradeCount: 29, avgRating: 5.0, joinedMonths: 99)
        XCTAssertEqual(result, .trusted)
    }

    // MARK: - warmNeighbor 티어

    /// tradeCount=9(trusted 미달), rating=5.0이지만 거래 3회 이상 → warmNeighbor
    func test_tier_trade9HighRating_returnsWarmNeighbor() {
        let result = TierCalculator.tier(tradeCount: 9, avgRating: 5.0, joinedMonths: 99)
        XCTAssertEqual(result, .warmNeighbor)
    }

    /// warmNeighbor 최솟값: tradeCount=3, 평점·가입 무관(0) → warmNeighbor
    /// 평점 조건이 없음을 명시적으로 검증
    func test_tier_warmNeighborMinimum_returnsWarmNeighbor() {
        let result = TierCalculator.tier(tradeCount: 3, avgRating: 0.0, joinedMonths: 0)
        XCTAssertEqual(result, .warmNeighbor)
    }

    // MARK: - sprout 티어

    /// tradeCount=2(3 미만), 평점·가입 최대치여도 → sprout
    func test_tier_trade2HighRatingLongJoined_returnsSprout() {
        let result = TierCalculator.tier(tradeCount: 2, avgRating: 5.0, joinedMonths: 99)
        XCTAssertEqual(result, .sprout)
    }

    /// 모든 값 0 (신규 가입) → sprout
    func test_tier_allZero_returnsSprout() {
        let result = TierCalculator.tier(tradeCount: 0, avgRating: 0.0, joinedMonths: 0)
        XCTAssertEqual(result, .sprout)
    }
}
