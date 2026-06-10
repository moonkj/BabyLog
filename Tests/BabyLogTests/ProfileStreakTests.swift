// ProfileStreakTests.swift
// BabyLogTests — 연속 기록일 계산 회귀 방지

import XCTest
@testable import BabyLog

final class ProfileStreakTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ offset: Int, from base: Date) -> Date {
        cal.date(byAdding: .day, value: offset, to: base)!
    }

    func test_emptyDiary_returnsZero() {
        XCTAssertEqual(ProfileStreak.currentStreak(diaryDates: [], calendar: cal), 0)
    }

    func test_todayPlusYesterday_returnsTwo() {
        let today = cal.startOfDay(for: Date())
        let dates = [today, day(-1, from: today)]
        XCTAssertEqual(ProfileStreak.currentStreak(diaryDates: dates, calendar: cal, today: today), 2)
    }

    func test_noTodayButYesterday_streakMaintained() {
        // 오늘 기록 없어도 어제까지 이어졌으면 유지 (죄책감 방지)
        let today = cal.startOfDay(for: Date())
        let dates = [day(-1, from: today), day(-2, from: today)]
        XCTAssertEqual(ProfileStreak.currentStreak(diaryDates: dates, calendar: cal, today: today), 2)
    }

    func test_gapBreaksStreak() {
        let today = cal.startOfDay(for: Date())
        // 오늘, (어제 없음), 그제 → 오늘만 streak 1
        let dates = [today, day(-2, from: today), day(-3, from: today)]
        XCTAssertEqual(ProfileStreak.currentStreak(diaryDates: dates, calendar: cal, today: today), 1)
    }

    func test_staleRecords_returnsZero() {
        let today = cal.startOfDay(for: Date())
        let dates = [day(-5, from: today), day(-6, from: today)]
        XCTAssertEqual(ProfileStreak.currentStreak(diaryDates: dates, calendar: cal, today: today), 0)
    }

    func test_duplicateSameDay_countsOnce() {
        let today = cal.startOfDay(for: Date())
        let dates = [today, today, today]
        XCTAssertEqual(ProfileStreak.currentStreak(diaryDates: dates, calendar: cal, today: today), 1)
    }
}
