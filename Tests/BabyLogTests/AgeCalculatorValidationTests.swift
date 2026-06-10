// AgeCalculatorValidationTests.swift
// BabyLogTests
//
// QA — 새 검증 동작 및 경계 케이스 단위 테스트
// 계약: pregnancyWeeks(미래 LMP/양쪽 nil), childAgeMonths(미래 출생), dPlusDays(미래 출생) → 방어적 반환
// 기존 정상 케이스 회귀 보호 포함.

import XCTest
@testable import BabyLog

final class AgeCalculatorValidationTests: XCTestCase {

    // MARK: - Helper

    /// "yyyy-MM-dd" 문자열을 현지 그레고리안 자정(startOfDay)으로 변환
    private func d(_ s: String) -> Date {
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

    // MARK: - pregnancyWeeks: 미래 LMP (asOf < lmp)

    /// lmp=2025-02-01, edd=nil, asOf=2025-01-08 → lmp가 asOf보다 미래이므로 nil 반환.
    /// 계약: totalDays < 0 → nil. 아직 임신이 시작되지 않은 날짜 기준이면 무효 결과 대신 nil.
    func test_pregnancyWeeks_futureLmp_returnsNil() {
        let result = AgeCalculator.pregnancyWeeks(
            lmp: d("2025-02-01"),
            edd: nil,
            asOf: d("2025-01-08")
        )
        XCTAssertNil(result,
            "asOf가 lmp보다 이전이면(미래 시작) nil을 반환해야 한다")
    }

    // MARK: - pregnancyWeeks: lmp·edd 양쪽 nil

    /// lmp=nil, edd=nil, asOf=임의 날짜 → nil 반환.
    func test_pregnancyWeeks_bothNil_anyAsOf_returnsNil() {
        let result = AgeCalculator.pregnancyWeeks(
            lmp: nil,
            edd: nil,
            asOf: d("2025-06-10")
        )
        XCTAssertNil(result,
            "lmp와 edd가 모두 nil이면 nil을 반환해야 한다")
    }

    // MARK: - childAgeMonths: 미래 출생일 (asOf < birthDate)

    /// birthDate=2025-06-01, asOf=2025-05-31 → 출생 전이므로 (0, 0) 반환.
    /// 계약: Calendar.dateComponents는 음수를 반환할 수 있으나,
    /// 아직 태어나지 않은 아이의 월령은 (0, 0)으로 방어 처리되어야 한다.
    func test_childAgeMonths_futureBirthDate_returnsZeroZero() {
        let result = AgeCalculator.childAgeMonths(
            birthDate: d("2025-06-01"),
            asOf: d("2025-05-31")
        )
        XCTAssertEqual(result.months, 0,
            "미래 출생일 기준 months는 0이어야 한다 — 방어적 처리 필요")
        XCTAssertEqual(result.days, 0,
            "미래 출생일 기준 days는 0이어야 한다 — 방어적 처리 필요")
    }

    // MARK: - dPlusDays: 미래 출생일 (asOf < birthDate)

    /// birthDate=2025-06-01, asOf=2025-05-31 → 출생 전이므로 0 반환.
    /// 계약: 아직 태어나지 않은 날에 dPlusDays를 호출하면 0을 반환해야 한다(음수 금지).
    func test_dPlusDays_futureBirthDate_returnsZero() {
        let result = AgeCalculator.dPlusDays(
            birthDate: d("2025-06-01"),
            asOf: d("2025-05-31")
        )
        XCTAssertEqual(result, 0,
            "미래 출생일 기준 dPlusDays는 0이어야 한다 — 방어적 처리 필요")
    }

    // MARK: - 회귀 보호: dPlusDays 당일 = 1

    /// 출생 당일: birthDate=asOf → 1 (기존 정상 동작 회귀 보호)
    func test_dPlusDays_birthDay_returns1_regression() {
        let result = AgeCalculator.dPlusDays(
            birthDate: d("2025-06-01"),
            asOf: d("2025-06-01")
        )
        XCTAssertEqual(result, 1,
            "출생 당일은 D+1이어야 한다 — 회귀 보호")
    }

    // MARK: - 회귀 보호: childAgeMonths 14개월 5일

    /// birthDate=2024-01-15, asOf=2025-03-20 → (14, 5) (기존 정상 동작 회귀 보호)
    func test_childAgeMonths_14months5days_regression() {
        let result = AgeCalculator.childAgeMonths(
            birthDate: d("2024-01-15"),
            asOf: d("2025-03-20")
        )
        XCTAssertEqual(result.months, 14,
            "14개월 케이스 회귀 보호 — months=14 이어야 한다")
        XCTAssertEqual(result.days, 5,
            "14개월 케이스 회귀 보호 — days=5 이어야 한다")
    }
}
