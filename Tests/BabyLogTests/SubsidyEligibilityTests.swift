// SubsidyEligibilityTests.swift
// MockSubsidyProvider 연령 게이팅 — 잘못된(부적격) 지원금 노출 방지(정직 원칙).

import XCTest
@testable import BabyLog

final class SubsidyEligibilityTests: XCTestCase {

    private let provider = MockSubsidyProvider()

    func test_infant6mo_includesFirstMeetAndParentBenefit() async throws {
        let result = try await provider.subsidies(childAgeMonths: 6)
        let ids = Set(result.map(\.id))
        XCTAssertTrue(ids.contains("subsidy-001"), "출생1년이내 → 첫만남이용권 포함")
        XCTAssertTrue(ids.contains("subsidy-002"), "0~11개월 → 부모급여(100만)")
        XCTAssertTrue(ids.contains("subsidy-004"), "아동수당")
        XCTAssertEqual(result.count, 5)
    }

    func test_18mo_excludesFirstMeet_usesReducedParentBenefit() async throws {
        let result = try await provider.subsidies(childAgeMonths: 18)
        let ids = Set(result.map(\.id))
        XCTAssertFalse(ids.contains("subsidy-001"), "12개월↑ → 첫만남이용권 제외")
        XCTAssertFalse(ids.contains("subsidy-002"), "0~11 부모급여 제외")
        XCTAssertTrue(ids.contains("subsidy-003"), "12~23 부모급여(50만)")
    }

    func test_olderThan96mo_returnsEmpty() async throws {
        let result = try await provider.subsidies(childAgeMonths: 100)
        XCTAssertTrue(result.isEmpty, "만 8세 이상은 적용 지원금 없음")
    }

    func test_eligibilityMonotonicallyNarrowsWithAge() async throws {
        let young = try await provider.subsidies(childAgeMonths: 6).count
        let mid   = try await provider.subsidies(childAgeMonths: 30).count
        XCTAssertGreaterThan(young, mid, "나이가 들수록 적용 지원금이 줄어든다")
    }

    func test_allApplyURLsPointToBokjiro() async throws {
        let result = try await provider.subsidies(childAgeMonths: 6)
        for s in result {
            XCTAssertEqual(s.applyURL?.host, "www.bokjiro.go.kr", "\(s.name) 신청 링크는 복지로여야 함")
        }
    }

    func test_firstMeetIsLumpSum() async throws {
        let result = try await provider.subsidies(childAgeMonths: 3)
        let firstMeet = result.first { $0.id == "subsidy-001" }
        XCTAssertEqual(firstMeet?.isLumpSum, true, "첫만남이용권은 일시금(월지급 오표기 방지)")
    }
}
