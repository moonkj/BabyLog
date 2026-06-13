// BudgetPeriodTests.swift
// BudgetSummary 기간 집계(periodStart/inPeriod/total/previousTotal/yearTotal/yearToDate/trend)
// — 트리맵/기간차트 도입분으로 기존 monthlyTotal/byCategory 외 미검증 로직.

import XCTest
@testable import BabyLog

final class BudgetPeriodTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()
    private func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: day, hour: h))!
    }
    private func exp(_ amount: Int, _ date: Date) -> Expense {
        Expense(amount: amount, category: .etc, date: date)
    }

    func test_periodStart_week_is6DaysBeforeStartOfDay() {
        let now = d(2026, 6, 13, 15)
        XCTAssertEqual(BudgetSummary.periodStart(.week, now: now, calendar: cal),
                       cal.startOfDay(for: d(2026, 6, 7)))
    }

    func test_inPeriod_includesStartBoundary_excludesOlder() {
        let now = d(2026, 6, 13)
        let inside = exp(100, cal.startOfDay(for: d(2026, 6, 7)))  // 경계(포함)
        let older  = exp(999, d(2026, 6, 6, 23))                   // 직전(제외)
        let result = BudgetSummary.inPeriod([inside, older], .week, now: now, calendar: cal)
        XCTAssertEqual(result.map(\.amount), [100])
    }

    func test_total_isInclusiveOnBothEnds() {
        let xs = [exp(100, d(2026, 6, 1)), exp(200, d(2026, 6, 30)), exp(50, d(2026, 5, 31))]
        XCTAssertEqual(BudgetSummary.total(xs, from: d(2026, 6, 1), to: d(2026, 6, 30, 23)), 300)
    }

    func test_previousTotal_week_noGapNoOverlapWithCurrentStart() {
        let now = d(2026, 6, 13)
        let currentStart = BudgetSummary.periodStart(.week, now: now, calendar: cal) // 6/7 00:00
        let inPrev = exp(100, d(2026, 6, 1))           // [5/31, 6/7) 안
        let atCurrentStart = exp(500, currentStart)    // 현재 구간 시작 → 직전에서 제외
        let tooOld = exp(9, d(2026, 5, 30))            // 직전보다 더 과거
        XCTAssertEqual(BudgetSummary.previousTotal([inPrev, atCurrentStart, tooOld], .week, now: now, calendar: cal), 100)
    }

    func test_yearTotal_filtersByYear() {
        let xs = [exp(100, d(2025, 1, 1)), exp(200, d(2026, 7, 1)), exp(300, d(2026, 12, 31))]
        XCTAssertEqual(BudgetSummary.yearTotal(xs, year: 2026, calendar: cal), 500)
    }

    func test_yearToDate_pastYear_cutsAtParallelAsOfDate() {
        let now = d(2026, 3, 15)
        let early = exp(100, d(2025, 2, 1))      // cutoff(2025-03-15) 이전 → 포함
        let after = exp(999, d(2025, 6, 1))      // cutoff 이후 → 제외(올해 부분합과 공정 비교)
        XCTAssertEqual(BudgetSummary.yearToDateTotal([early, after], year: 2025, asOf: now, calendar: cal), 100)
    }

    func test_trend_week_has7DailyBuckets_includingZeroDays() {
        let now = d(2026, 6, 13)
        let xs = [exp(100, d(2026, 6, 13, 9)), exp(50, d(2026, 6, 7, 9))]
        let buckets = BudgetSummary.trend(xs, .week, now: now, calendar: cal)
        XCTAssertEqual(buckets.count, 7)
        XCTAssertEqual(buckets.map(\.amount).reduce(0, +), 150)
        XCTAssertEqual(buckets.last?.amount, 100)   // 오늘 버킷
    }

    func test_trend_year_has12MonthlyBuckets() {
        let now = d(2026, 6, 13)
        let buckets = BudgetSummary.trend([exp(100, d(2026, 6, 1))], .year, now: now, calendar: cal)
        XCTAssertEqual(buckets.count, 12)
        XCTAssertEqual(buckets.map(\.amount).reduce(0, +), 100)
    }
}
