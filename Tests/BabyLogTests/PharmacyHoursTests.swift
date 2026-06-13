// PharmacyHoursTests.swift
// 응급의료포털 약국 영업시간 판정(ERPharmacyItem.isOpen) — 요일/자정넘김/경계/휴무.
// KST 기준. 2026-06-15는 월요일(dutyTime index 1).

import XCTest
@testable import BabyLog

final class PharmacyHoursTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()
    private func kst(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ mi: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi))!
    }
    private func item(_ json: String) throws -> ERPharmacyItem {
        try JSONDecoder().decode(ERPharmacyItem.self, from: Data(json.utf8))
    }

    // 월 09:00~18:00
    private let monRegular = #"{"dutyName":"가나약국","wgs84Lat":37.5,"wgs84Lon":127.0,"dutyTime1s":900,"dutyTime1c":1800}"#

    func test_openDuringHours() throws {
        XCTAssertTrue(try item(monRegular).isOpen(at: kst(2026, 6, 15, 10)))   // 월 10:00
    }
    func test_closedBeforeOpen() throws {
        XCTAssertFalse(try item(monRegular).isOpen(at: kst(2026, 6, 15, 8)))   // 월 08:00
    }
    func test_closedAtClosingMinute_exclusiveEnd() throws {
        XCTAssertFalse(try item(monRegular).isOpen(at: kst(2026, 6, 15, 18)))  // 18:00 정각 = 종료
    }
    func test_closedOnDayWithoutHours() throws {
        // 화요일(dutyTime2*) 정보 없음 → 휴무
        XCTAssertFalse(try item(monRegular).isOpen(at: kst(2026, 6, 16, 10)))  // 화 10:00
    }

    // 월 22:00~06:00 (자정 넘김)
    private let monOvernight = #"{"dutyName":"야간약국","wgs84Lat":37.5,"wgs84Lon":127.0,"dutyTime1s":2200,"dutyTime1c":600}"#

    func test_overnight_openLateNight() throws {
        XCTAssertTrue(try item(monOvernight).isOpen(at: kst(2026, 6, 15, 23)))  // 월 23:00
    }
    func test_overnight_openAfterMidnight() throws {
        XCTAssertTrue(try item(monOvernight).isOpen(at: kst(2026, 6, 15, 3)))   // 월 03:00 (< 06:00)
    }
    func test_overnight_closedMidday() throws {
        XCTAssertFalse(try item(monOvernight).isOpen(at: kst(2026, 6, 15, 12))) // 월 12:00
    }

    func test_startEqualsEnd_isClosed() throws {
        let it = try item(#"{"dutyName":"x","wgs84Lat":37.5,"wgs84Lon":127.0,"dutyTime1s":900,"dutyTime1c":900}"#)
        XCTAssertFalse(it.isOpen(at: kst(2026, 6, 15, 9)))
    }

    func test_noHoursAtAll_isClosed() throws {
        let it = try item(#"{"dutyName":"무정보","wgs84Lat":37.5,"wgs84Lon":127.0}"#)
        XCTAssertFalse(it.isOpen(at: kst(2026, 6, 15, 12)))
    }

    func test_stringTimeValuesAreParsed() throws {
        // dutyTime이 문자열("0830")로 와도 관대 파싱
        let it = try item(#"{"dutyName":"문자열","wgs84Lat":37.5,"wgs84Lon":127.0,"dutyTime1s":"0830","dutyTime1c":"1700"}"#)
        XCTAssertTrue(it.isOpen(at: kst(2026, 6, 15, 9)))
    }
}
