// MemoryReminderTests.swift
// BabyLogTests — "N년 전 오늘" 추억 알림 빌더 회귀 방지

import XCTest
@testable import BabyLog

final class MemoryReminderTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func test_buildsForUpcomingAnniversary() {
        let now = day(2026, 6, 1)
        let e = DiaryEntry(childId: UUID(), date: day(2025, 7, 10), recordType: "photo", photoRef: "a.jpg")
        let reqs = NotificationScheduler.memoryReminders(diaryEntries: [e], childName: "지호", now: now, calendar: cal)
        XCTAssertEqual(reqs.count, 1)
        XCTAssertTrue(reqs[0].title.contains("1년 전"))
        XCTAssertTrue(reqs[0].fireDate > now)
    }

    func test_skipsEntriesWithoutPhoto() {
        let now = day(2026, 6, 1)
        let e = DiaryEntry(childId: UUID(), date: day(2025, 7, 10), recordType: "diary") // 사진 없음
        XCTAssertTrue(NotificationScheduler.memoryReminders(diaryEntries: [e], childName: "지호", now: now, calendar: cal).isEmpty)
    }

    func test_oncePerMonth() {
        let now = day(2026, 6, 1)
        // 같은 달(7월)의 두 사진 → 주년도 같은 달 → 1건만
        let e1 = DiaryEntry(childId: UUID(), date: day(2025, 7, 10), recordType: "photo", photoRef: "a.jpg")
        let e2 = DiaryEntry(childId: UUID(), date: day(2025, 7, 20), recordType: "photo", photoRef: "b.jpg")
        let reqs = NotificationScheduler.memoryReminders(diaryEntries: [e1, e2], childName: "지호", now: now, calendar: cal)
        XCTAssertEqual(reqs.count, 1)
    }

    func test_separateMonthsBothScheduled() {
        let now = day(2026, 6, 1)
        let e1 = DiaryEntry(childId: UUID(), date: day(2025, 7, 10), recordType: "photo", photoRef: "a.jpg")
        let e2 = DiaryEntry(childId: UUID(), date: day(2025, 9, 10), recordType: "photo", photoRef: "b.jpg")
        let reqs = NotificationScheduler.memoryReminders(diaryEntries: [e1, e2], childName: "지호", now: now, calendar: cal)
        XCTAssertEqual(reqs.count, 2)  // 7월·9월 → 각 1건
    }
}
