// TierCalculatorProgressTests.swift
// TierCalculator의 진행률/남은거래/기준치 헬퍼(프로필 진행바) — 기존 tier() 외 미검증 분기.

import XCTest
@testable import BabyLog

final class TierCalculatorProgressTests: XCTestCase {

    // MARK: tradesNeededForNext
    func test_tradesNeeded_sprout() {
        XCTAssertEqual(TierCalculator.tradesNeededForNext(currentTier: .sprout, tradeCount: 1), 2)
    }
    func test_tradesNeeded_warmNeighbor() {
        XCTAssertEqual(TierCalculator.tradesNeededForNext(currentTier: .warmNeighbor, tradeCount: 6), 4)
    }
    func test_tradesNeeded_trusted() {
        XCTAssertEqual(TierCalculator.tradesNeededForNext(currentTier: .trusted, tradeCount: 25), 5)
    }
    func test_tradesNeeded_golden_isZero() {
        XCTAssertEqual(TierCalculator.tradesNeededForNext(currentTier: .golden, tradeCount: 999), 0)
    }
    func test_tradesNeeded_neverNegative() {
        XCTAssertEqual(TierCalculator.tradesNeededForNext(currentTier: .warmNeighbor, tradeCount: 50), 0)
    }

    // MARK: tradeThresholdForNext
    func test_threshold() {
        XCTAssertEqual(TierCalculator.tradeThresholdForNext(currentTier: .sprout), 3)
        XCTAssertEqual(TierCalculator.tradeThresholdForNext(currentTier: .warmNeighbor), 10)
        XCTAssertEqual(TierCalculator.tradeThresholdForNext(currentTier: .trusted), 30)
    }

    // MARK: progress (구간 내 진행률)
    func test_progress_warmNeighbor_midSegment() {
        // 구간 [3,10): 6거래 → (6-3)/(10-3) ≈ 0.4286
        XCTAssertEqual(TierCalculator.progress(tradeCount: 6, currentTier: .warmNeighbor), 3.0/7.0, accuracy: 0.0001)
    }
    func test_progress_clampedToOne() {
        XCTAssertEqual(TierCalculator.progress(tradeCount: 100, currentTier: .trusted), 1.0, accuracy: 0.0001)
    }
    func test_progress_atSegmentStartIsZero() {
        XCTAssertEqual(TierCalculator.progress(tradeCount: 3, currentTier: .warmNeighbor), 0.0, accuracy: 0.0001)
    }
    func test_progress_golden_isFull() {
        XCTAssertEqual(TierCalculator.progress(tradeCount: 30, currentTier: .golden), 1.0, accuracy: 0.0001)
    }

    // MARK: 골든 호칭 중립성(성별 중립 원칙)
    func test_goldenDisplayName_isGenderNeutral() {
        XCTAssertFalse(Tier.golden.displayName.contains("맘"), "티어 표기에 '맘'이 들어가면 안 됨(성별 중립)")
        XCTAssertFalse(Tier.golden.displayName.contains("파파"))
    }
}
