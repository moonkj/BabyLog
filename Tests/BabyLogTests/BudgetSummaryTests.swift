// BudgetSummaryTests.swift
// BabyLogTests
//
// QA — BudgetSummary 순수 계산 계약 검증
//
// ─── 계약과 어긋날 수 있는 지점 ───────────────────────────────────────────────
//
// [1] ExpenseCategory case명 — 현재 BudgetModels.swift 기준:
//       .diaper / .clothing / .medical / .education / .play / .transport / .etc
//     코더가 case명을 변경하거나 추가·삭제하면 이 파일의 Expense 생성 코드가
//     컴파일 에러를 낸다.
//
// [2] amount 타입 — 계약은 Int(원화). 코더가 Double로 바꾸면 테스트 값이 틀릴 수 있다.
//
// [3] autoCollected 필드 — 계약에 따르면 monthlyTotal/byCategory는 autoCollected
//     여부와 무관하게 모든 항목을 합산한다. 코더가 autoCollected=true인 항목을
//     제외하는 필터를 추가하면 테스트가 레드로 전환된다.
//
// [4] calendar 파라미터 — 테스트는 Calendar(identifier: .gregorian)을 주입해
//     .current에 의존하지 않는다. 코더가 파라미터를 제거하면 API 불일치.
//
// [5] byCategory 반환 타입 — 지출이 없는 카테고리는 결과 딕셔너리에 키 자체가
//     없어야 한다(값 0이 아님). 코더가 모든 케이스를 0으로 초기화하면
//     test_byCategory_missingCategoryNotPresent가 실패한다.
//
// ─────────────────────────────────────────────────────────────────────────────

import XCTest
@testable import BabyLog

final class BudgetSummaryTests: XCTestCase {

    // MARK: - Helpers

    /// "yyyy-MM-dd" 문자열을 그레고리안 자정으로 변환
    private func d(_ s: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: s) else {
            fatalError("날짜 파싱 실패: \(s)")
        }
        return date
    }

    /// 테스트 전용 그레고리안 캘린더 (Seoul 고정)
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }

    // MARK: - monthlyTotal: 기본 케이스

    /// 빈 배열이면 0을 반환한다.
    func test_monthlyTotal_emptyArray_returnsZero() {
        let result = BudgetSummary.monthlyTotal([], in: d("2025-06-01"), calendar: cal)
        XCTAssertEqual(result, 0)
    }

    /// 같은 연·월 항목 1개만 있을 때 해당 amount를 반환한다.
    func test_monthlyTotal_singleItemSameMonth() {
        let expense = Expense(amount: 15_000, category: .diaper, date: d("2025-06-15"))
        let result = BudgetSummary.monthlyTotal([expense], in: d("2025-06-01"), calendar: cal)
        XCTAssertEqual(result, 15_000)
    }

    /// 같은 달 여러 항목의 합산이 맞는지 검증한다.
    func test_monthlyTotal_multipleItemsSameMonth_sumsAll() {
        let expenses = [
            Expense(amount: 10_000, category: .diaper,   date: d("2025-06-01")),
            Expense(amount: 20_000, category: .clothing,  date: d("2025-06-15")),
            Expense(amount:  5_000, category: .medical,   date: d("2025-06-30")),
        ]
        let result = BudgetSummary.monthlyTotal(expenses, in: d("2025-06-10"), calendar: cal)
        XCTAssertEqual(result, 35_000)
    }

    // MARK: - monthlyTotal: 다른 달 제외

    /// 이전 달 항목은 합산에서 제외된다.
    func test_monthlyTotal_excludesPreviousMonth() {
        let expenses = [
            Expense(amount: 10_000, category: .diaper, date: d("2025-05-31")), // 5월 — 제외
            Expense(amount: 30_000, category: .diaper, date: d("2025-06-01")), // 6월 — 포함
        ]
        let result = BudgetSummary.monthlyTotal(expenses, in: d("2025-06-01"), calendar: cal)
        XCTAssertEqual(result, 30_000)
    }

    /// 다음 달 항목은 합산에서 제외된다.
    func test_monthlyTotal_excludesNextMonth() {
        let expenses = [
            Expense(amount: 50_000, category: .education, date: d("2025-06-28")), // 6월 — 포함
            Expense(amount: 20_000, category: .education, date: d("2025-07-01")), // 7월 — 제외
        ]
        let result = BudgetSummary.monthlyTotal(expenses, in: d("2025-06-15"), calendar: cal)
        XCTAssertEqual(result, 50_000)
    }

    /// 연도가 달라지는 경계: 2024-12월과 2025-01월이 혼재할 때 정확히 분리된다.
    func test_monthlyTotal_yearBoundary_excludesDifferentYear() {
        let expenses = [
            Expense(amount: 100_000, category: .medical, date: d("2024-12-31")), // 2024-12 — 제외
            Expense(amount:  80_000, category: .medical, date: d("2025-01-01")), // 2025-01 — 포함
        ]
        let result = BudgetSummary.monthlyTotal(expenses, in: d("2025-01-15"), calendar: cal)
        XCTAssertEqual(result, 80_000)
    }

    /// 기준 날짜의 일(day) 값은 월 필터에 영향을 주지 않는다.
    func test_monthlyTotal_dayOfMonthDoesNotAffectFilter() {
        let expenses = [
            Expense(amount: 7_000, category: .play, date: d("2025-03-01")),
            Expense(amount: 3_000, category: .play, date: d("2025-03-31")),
        ]
        // 기준 날짜를 월 중간(2025-03-15)으로 주어도 결과 동일
        let result = BudgetSummary.monthlyTotal(expenses, in: d("2025-03-15"), calendar: cal)
        XCTAssertEqual(result, 10_000)
    }

    /// autoCollected=true 항목도 합산에 포함된다.
    func test_monthlyTotal_includesAutoCollectedItems() {
        let expenses = [
            Expense(amount: 12_000, category: .transport, date: d("2025-06-10"),
                    autoCollected: false),
            Expense(amount:  8_000, category: .transport, date: d("2025-06-20"),
                    autoCollected: true),  // 자동 수집 항목
        ]
        let result = BudgetSummary.monthlyTotal(expenses, in: d("2025-06-01"), calendar: cal)
        XCTAssertEqual(result, 20_000)
    }

    // MARK: - byCategory: 기본 케이스

    /// 빈 배열이면 빈 딕셔너리를 반환한다.
    func test_byCategory_emptyArray_returnsEmptyDict() {
        let result = BudgetSummary.byCategory([])
        XCTAssertTrue(result.isEmpty)
    }

    /// 단일 항목 — 해당 카테고리 키만 존재하고 값이 amount와 동일하다.
    func test_byCategory_singleItem_correctCategory() {
        let expense = Expense(amount: 25_000, category: .medical, date: d("2025-06-01"))
        let result = BudgetSummary.byCategory([expense])
        XCTAssertEqual(result[.medical], 25_000)
        XCTAssertEqual(result.count, 1)
    }

    /// 동일 카테고리 항목이 여러 개일 때 누적 합산된다.
    func test_byCategory_sameCategory_accumulates() {
        let expenses = [
            Expense(amount: 10_000, category: .diaper, date: d("2025-06-01")),
            Expense(amount: 20_000, category: .diaper, date: d("2025-06-10")),
            Expense(amount:  5_000, category: .diaper, date: d("2025-06-20")),
        ]
        let result = BudgetSummary.byCategory(expenses)
        XCTAssertEqual(result[.diaper], 35_000)
        XCTAssertEqual(result.count, 1, "같은 카테고리끼리는 키가 하나여야 한다")
    }

    /// 여러 카테고리가 섞인 경우 각 카테고리별 합계가 정확하다.
    func test_byCategory_multipleCategories_eachCorrect() {
        let expenses = [
            Expense(amount: 15_000, category: .diaper,    date: d("2025-06-01")),
            Expense(amount: 30_000, category: .education, date: d("2025-06-05")),
            Expense(amount: 12_000, category: .diaper,    date: d("2025-06-10")),
            Expense(amount: 10_000, category: .play,      date: d("2025-06-15")),
            Expense(amount:  8_000, category: .education, date: d("2025-06-20")),
        ]
        let result = BudgetSummary.byCategory(expenses)
        XCTAssertEqual(result[.diaper],    27_000)
        XCTAssertEqual(result[.education], 38_000)
        XCTAssertEqual(result[.play],      10_000)
        XCTAssertEqual(result.count, 3)
    }

    /// 지출이 없는 카테고리는 결과 딕셔너리에 키 자체가 존재하지 않아야 한다.
    func test_byCategory_missingCategoryNotPresent() {
        let expenses = [
            Expense(amount: 5_000, category: .clothing, date: d("2025-06-01")),
        ]
        let result = BudgetSummary.byCategory(expenses)
        XCTAssertNil(result[.medical],   "의료 지출이 없으면 키가 없어야 한다")
        XCTAssertNil(result[.education], "교육 지출이 없으면 키가 없어야 한다")
    }

    /// 모든 카테고리에 걸쳐 항목이 있을 때 ExpenseCategory.allCases 수와 결과 키 수가 같다.
    func test_byCategory_allCategories_keyCountMatchesAllCases() {
        let expenses = ExpenseCategory.allCases.map { cat in
            Expense(amount: 1_000, category: cat, date: d("2025-06-01"))
        }
        let result = BudgetSummary.byCategory(expenses)
        XCTAssertEqual(result.count, ExpenseCategory.allCases.count)
        for cat in ExpenseCategory.allCases {
            XCTAssertEqual(result[cat], 1_000, "\(cat) 카테고리 값이 1000이어야 한다")
        }
    }
}
