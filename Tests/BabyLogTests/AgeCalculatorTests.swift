// AgeCalculatorTests.swift
// BabyLogTests
//
// QA Teammate 3 작성 — 코더(Teammate 1) API 계약 기반 단위 테스트
//
// TODO (리뷰어 관점 — 누락/위험 케이스):
// 1. 윤년 경계: birthDate=2024-02-29 기준 월령·D+ 계산 (2025-02-28 vs 2025-03-01)
// 2. DST(일광절약시간) 전환일 자정: 현지 startOfDay가 UTC 1시간 편차를 흡수하는지 확인
// 3. pregnancyWeeks 음수 방어: asOf < conceptionBase → nil 반환 여부 (현재 구현은 totalDays < 0 → nil)
// 4. EDD 기준 임신 40주 당일: (edd-280)+280 == edd → (40,0) 확인
// 5. childAgeMonths 생일 당일: asOf == birthDate → (0,0) 확인
// 6. dPlusDays 초과 케이스: 음수 asOf (출생 이전) → 0 또는 음수 반환 정책 미정
// 7. 쌍둥이(fetusCount=2): AgeCalculator 자체는 fetusCount 무관하나 통합 시 twin-specific 로직 확인
// 8. 로케일 독립성: Calendar.current가 비-그레고리안 로케일(예: 히브리력)에서도 .gregorian 고정인지 확인

import XCTest
@testable import BabyLog

final class AgeCalculatorTests: XCTestCase {

    // MARK: - Helpers

    /// "yyyy-MM-dd" 문자열을 현지 그레고리안 자정(startOfDay)으로 변환
    func d(_ s: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: s) else {
            fatalError("날짜 파싱 실패: \(s)")
        }
        return date
    }

    // MARK: - pregnancyWeeks

    /// LMP만 있을 때: lmp=2025-01-01, asOf=2025-01-08 → (1, 0)
    func test_pregnancyWeeks_lmpOnly_1week() {
        let result = AgeCalculator.pregnancyWeeks(
            lmp: d("2025-01-01"),
            edd: nil,
            asOf: d("2025-01-08")
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.weeks, 1)
        XCTAssertEqual(result?.days, 0)
    }

    /// EDD 우선: lmp=2025-01-01, edd=2025-10-15, asOf=2025-01-15
    /// edd 기준 base = 2025-10-15 - 280일 = 2025-01-08
    /// asOf - base = 7일 → (1, 0)
    func test_pregnancyWeeks_eddPriority() {
        // 2025-10-15 - 280 days → let Swift compute expected base
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let edd = d("2025-10-15")
        let base = cal.date(byAdding: .day, value: -280, to: cal.startOfDay(for: edd))!
        let asOf = d("2025-01-15")
        let components = cal.dateComponents([.day], from: base, to: cal.startOfDay(for: asOf))
        let totalDays = components.day ?? -1

        // 사전 확인: 스펙이 (1,0)을 가정하려면 totalDays == 7 이어야 함
        // 실제 edd=2025-10-15 - 280 = 2025-01-08 → asOf 2025-01-15 까지 7일 → (1,0)
        let result = AgeCalculator.pregnancyWeeks(
            lmp: d("2025-01-01"),
            edd: d("2025-10-15"),
            asOf: d("2025-01-15")
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.weeks, totalDays / 7)
        XCTAssertEqual(result?.days, totalDays % 7)
        // 스펙 고정값 검증
        XCTAssertEqual(result?.weeks, 1)
        XCTAssertEqual(result?.days, 0)
    }

    /// lmp=nil, edd=nil → nil 반환
    func test_pregnancyWeeks_bothNil_returnsNil() {
        let result = AgeCalculator.pregnancyWeeks(
            lmp: nil,
            edd: nil,
            asOf: d("2025-06-10")
        )
        XCTAssertNil(result)
    }

    /// EDD만 있을 때 정상 동작 (lmp=nil)
    func test_pregnancyWeeks_eddOnly_noLmp() {
        let result = AgeCalculator.pregnancyWeeks(
            lmp: nil,
            edd: d("2025-10-15"),
            asOf: d("2025-01-15")
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.weeks, 1)
        XCTAssertEqual(result?.days, 0)
    }

    /// asOf == lmp (임신 당일) → (0, 0)
    func test_pregnancyWeeks_asOfEqualsLmp_zeroWeeks() {
        let result = AgeCalculator.pregnancyWeeks(
            lmp: d("2025-03-01"),
            edd: nil,
            asOf: d("2025-03-01")
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.weeks, 0)
        XCTAssertEqual(result?.days, 0)
    }

    // MARK: - childAgeMonths

    /// birthDate=2024-01-15, asOf=2025-03-20 → (14, 5)
    func test_childAgeMonths_14months5days() {
        let result = AgeCalculator.childAgeMonths(
            birthDate: d("2024-01-15"),
            asOf: d("2025-03-20")
        )
        XCTAssertEqual(result.months, 14)
        XCTAssertEqual(result.days, 5)
    }

    /// 생일 당일 → (0, 0)
    func test_childAgeMonths_sameDay_zeroZero() {
        let result = AgeCalculator.childAgeMonths(
            birthDate: d("2025-06-01"),
            asOf: d("2025-06-01")
        )
        XCTAssertEqual(result.months, 0)
        XCTAssertEqual(result.days, 0)
    }

    /// 정확히 1개월 후 → (1, 0)
    func test_childAgeMonths_exactly1Month() {
        let result = AgeCalculator.childAgeMonths(
            birthDate: d("2025-01-15"),
            asOf: d("2025-02-15")
        )
        XCTAssertEqual(result.months, 1)
        XCTAssertEqual(result.days, 0)
    }

    // MARK: - dPlusDays

    /// 출생 당일 → 1
    func test_dPlusDays_birthDay_returns1() {
        let result = AgeCalculator.dPlusDays(
            birthDate: d("2025-06-01"),
            asOf: d("2025-06-01")
        )
        XCTAssertEqual(result, 1)
    }

    /// 출생 다음날 → 2
    func test_dPlusDays_dayAfterBirth_returns2() {
        let result = AgeCalculator.dPlusDays(
            birthDate: d("2025-06-01"),
            asOf: d("2025-06-02")
        )
        XCTAssertEqual(result, 2)
    }

    /// 백일 케이스: birth + 99일 → 100
    func test_dPlusDays_hundredDays_returns100() {
        // 출생일 기준 +99일 후가 D+100
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let birth = d("2025-06-01")
        let hundredDay = cal.date(byAdding: .day, value: 99, to: birth)!

        let result = AgeCalculator.dPlusDays(birthDate: birth, asOf: hundredDay)
        XCTAssertEqual(result, 100)
    }

    /// 임의 50일 케이스: birth + 49일 → 50
    func test_dPlusDays_fiftyDays() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let birth = d("2025-01-01")
        let fiftiethDay = cal.date(byAdding: .day, value: 49, to: birth)!

        let result = AgeCalculator.dPlusDays(birthDate: birth, asOf: fiftiethDay)
        XCTAssertEqual(result, 50)
    }

    // MARK: - dDayToBirth

    /// edd=2025-10-08, asOf=2025-10-01 → 7 (7일 남음)
    func test_dDayToBirth_7daysRemaining() {
        let result = AgeCalculator.dDayToBirth(
            edd: d("2025-10-08"),
            asOf: d("2025-10-01")
        )
        XCTAssertEqual(result, 7)
    }

    /// edd=2025-10-08, asOf=2025-10-10 → -2 (2일 지남)
    func test_dDayToBirth_2daysPast() {
        let result = AgeCalculator.dDayToBirth(
            edd: d("2025-10-08"),
            asOf: d("2025-10-10")
        )
        XCTAssertEqual(result, -2)
    }

    /// edd == asOf → 0 (당일)
    func test_dDayToBirth_sameDay_returnsZero() {
        let result = AgeCalculator.dDayToBirth(
            edd: d("2025-10-08"),
            asOf: d("2025-10-08")
        )
        XCTAssertEqual(result, 0)
    }
}
