// PresentationEnumsTests.swift
// 표시용 enum의 모든 케이스가 레이블·아이콘·톤을 빠짐없이 제공하는지(3중 인코딩 완전성)
// + 성별 중립 원칙(맘/파파 미포함) 검증.

import XCTest
@testable import BabyLog

final class PresentationEnumsTests: XCTestCase {

    func test_expenseCategory_allCasesHaveLabelIconAccessibility() {
        for c in ExpenseCategory.allCases {
            XCTAssertFalse(c.displayName.isEmpty, "\(c) displayName 비어있음")
            XCTAssertFalse(c.systemIcon.isEmpty, "\(c) systemIcon 비어있음")
            XCTAssertFalse(c.accessibilityLabel.isEmpty, "\(c) accessibilityLabel 비어있음")
            _ = c.badgeTone
        }
    }

    func test_budgetPeriod_allCasesHaveLabels() {
        for p in BudgetPeriod.allCases {
            XCTAssertFalse(p.label.isEmpty)
            XCTAssertFalse(p.rangeLabel.isEmpty)
            XCTAssertFalse(p.id.isEmpty)
            XCTAssertGreaterThan(p.bucketCount, 0)
        }
        XCTAssertTrue(BudgetPeriod.week.isDaily)
        XCTAssertFalse(BudgetPeriod.year.isDaily)
    }

    func test_tier_allCasesHaveNeutralLabelIconTone() {
        for t in Tier.allCases {
            XCTAssertFalse(t.displayName.isEmpty)
            XCTAssertFalse(t.displayName.contains("맘"), "티어 표기 성별 중립 위반: \(t)")
            XCTAssertFalse(t.displayName.contains("파파"))
            XCTAssertFalse(t.systemIcon.isEmpty)
            _ = t.badgeTone
        }
    }

    func test_tier_nextChainTerminatesAtGolden() {
        XCTAssertEqual(Tier.sprout.next, .warmNeighbor)
        XCTAssertEqual(Tier.warmNeighbor.next, .trusted)
        XCTAssertEqual(Tier.trusted.next, .golden)
        XCTAssertNil(Tier.golden.next, "최상위 티어는 다음이 없어야 함")
    }

    func test_marketSellerTier_goldenIsGenderNeutral() {
        for t in [MarketSellerTier.golden, .warm, .new] {
            XCTAssertFalse(t.rawValue.isEmpty)
            XCTAssertFalse(t.rawValue.contains("맘"), "마켓 판매자 등급 성별 중립 위반: \(t)")
            _ = t.badgeTone
        }
        XCTAssertEqual(MarketSellerTier.golden.rawValue, "골든")
    }

    func test_marketItemGrade_allCasesHaveLabelAndTone() {
        for g in MarketItemGrade.allCases {
            XCTAssertFalse(g.label.isEmpty)
            XCTAssertFalse(g.systemIcon.isEmpty)
            _ = g.badgeTone
        }
    }
}
