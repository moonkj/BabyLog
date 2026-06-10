// NotificationSchedulerTests.swift
// BabyLogTests
//
// QA — NotificationScheduler.vaccineReminders(_:now:calendar:) 계약 검증
//
// ===== 코더와 어긋날 수 있는 지점 =====
//
// [1] D-0 당일 now와 fireDate가 정확히 같을 때 (d0 >= now) 포함 여부.
//     현재 구현은 `>=` 이므로 경계값 당일 9시 == now 일 때 포함된다.
//     코더가 `>` 로 바꾸면 test_futureVaccine_d0ExactlyNow_isIncluded 가 실패.
//
// [2] fireDate 오름차순 보장 — 현재 구현은 vaccines 입력 순서대로 append할 뿐이며
//     별도 정렬을 하지 않는다. 단일 VaccineRecord에서는 D-7 < D-1 < D-0 순이 보장되지만
//     복수 record가 섞일 경우 전체 결과 배열이 오름차순임을 구현이 보장하지 않는다.
//     → 복수 record 정렬 테스트(test_multipleVaccines_resultIsSortedByFireDate)는
//       코더가 결과에 sort를 추가해야 통과한다.
//
// [3] scheduledDate가 nil인 record는 스킵(0건). 현재 구현 일치. 계약 명세와 동일.
//
// [4] completedDate가 설정된 경우(이미 완료된 접종) 알림을 생성하지 않아야 한다는
//     계약이 명세에 명시되지 않았다. 현재 구현도 completedDate를 무시하고 scheduledDate
//     기준으로만 필터링한다. 코더가 completedDate 완료 접종에 대해 알림을 억제하면
//     test_completedVaccine_* 케이스가 달라질 수 있다.
//
// [5] 알림 id 형식은 "vax-<vaccineId>-d7/d1/d0". vaccineId에 특수문자 포함 시
//     id 충돌 위험. 테스트는 안전한 ASCII vaccineId만 사용.

import XCTest
@testable import BabyLog

final class NotificationSchedulerTests: XCTestCase {

    // MARK: - Helpers

    private var seoulCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }()

    /// "yyyy-MM-dd" → Asia/Seoul 자정(startOfDay) Date
    private func d(_ s: String) -> Date {
        let fmt = DateFormatter()
        fmt.calendar = seoulCalendar
        fmt.timeZone = TimeZone(identifier: "Asia/Seoul")!
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: s) else {
            fatalError("날짜 파싱 실패: \(s)")
        }
        return date
    }

    /// "yyyy-MM-dd" 날짜에 hour를 더한 Date (Asia/Seoul)
    private func d(_ s: String, hour: Int) -> Date {
        let base = d(s)
        return seoulCalendar.date(byAdding: .hour, value: hour, to: base)!
    }

    private func makeRecord(
        vaccineId: String = "bcg",
        childId: UUID = UUID(),
        scheduledDate: Date?,
        completedDate: Date? = nil
    ) -> VaccineRecord {
        VaccineRecord(
            id: UUID(),
            childId: childId,
            vaccineId: vaccineId,
            scheduledDate: scheduledDate,
            completedDate: completedDate,
            hospital: nil
        )
    }

    // MARK: - scheduledDate nil → 0건

    func test_scheduledDateNil_returnsEmpty() {
        let record = makeRecord(vaccineId: "bcg", scheduledDate: nil)
        let result = NotificationScheduler.vaccineReminders(
            [record],
            now: d("2026-06-10"),
            calendar: seoulCalendar
        )
        XCTAssertTrue(result.isEmpty,
            "scheduledDate가 nil이면 알림 요청이 생성되지 않아야 한다")
    }

    // MARK: - 빈 배열 → 0건

    func test_emptyInput_returnsEmpty() {
        let result = NotificationScheduler.vaccineReminders(
            [],
            now: d("2026-06-10"),
            calendar: seoulCalendar
        )
        XCTAssertTrue(result.isEmpty, "빈 배열 입력 시 결과도 비어야 한다")
    }

    // MARK: - 미래 접종 1건: now 이후 알림만 생성

    /// now = 접종일 8일 전 → D-7, D-1, D-0 세 건 모두 생성
    func test_futureVaccine_8DaysBefore_producesAllThreeReminders() {
        // scheduledDate = 2026-07-01, now = 2026-06-23 (8일 전 오전 8시)
        let scheduledDate = d("2026-07-01")
        let now = d("2026-06-23", hour: 8) // D-7 fireDate(오전9시)보다 이전
        let record = makeRecord(vaccineId: "hepb", scheduledDate: scheduledDate)

        let result = NotificationScheduler.vaccineReminders(
            [record],
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result.count, 3, "8일 전에는 D-7·D-1·D-0 세 건 모두 생성되어야 한다")
    }

    /// now = D-7 fireDate 이후, D-1·D-0만 생성
    func test_futureVaccine_after_d7_produces_d1_and_d0() {
        // scheduledDate = 2026-07-01, now = 2026-06-24 오후12시 (D-7 발사 후)
        let scheduledDate = d("2026-07-01")
        let now = d("2026-06-24", hour: 12) // D-7(2026-06-24 09:00) 이후
        let record = makeRecord(vaccineId: "hepb", scheduledDate: scheduledDate)

        let result = NotificationScheduler.vaccineReminders(
            [record],
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result.count, 2, "D-7 이후에는 D-1·D-0 두 건만 생성되어야 한다")
        XCTAssertFalse(result.contains(where: { $0.id == "vax-hepb-d7" }),
            "D-7 알림은 포함되지 않아야 한다")
        XCTAssertTrue(result.contains(where: { $0.id == "vax-hepb-d1" }),
            "D-1 알림이 포함되어야 한다")
        XCTAssertTrue(result.contains(where: { $0.id == "vax-hepb-d0" }),
            "D-0 알림이 포함되어야 한다")
    }

    /// now = 당일 D-0 fireDate(09:00) 이후 → 0건
    func test_futureVaccine_afterD0FireDate_producesZero() {
        let scheduledDate = d("2026-06-10")
        let now = d("2026-06-10", hour: 10) // D-0 09:00 이후
        let record = makeRecord(vaccineId: "bcg", scheduledDate: scheduledDate)

        let result = NotificationScheduler.vaccineReminders(
            [record],
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertTrue(result.isEmpty,
            "D-0 fireDate 이후 now이면 모든 알림이 과거이므로 0건이어야 한다")
    }

    // MARK: - 과거 접종 → 0건

    func test_pastVaccine_returnsEmpty() {
        // scheduledDate 1년 전
        let scheduledDate = d("2025-06-10")
        let now = d("2026-06-10")
        let record = makeRecord(vaccineId: "dtap", scheduledDate: scheduledDate)

        let result = NotificationScheduler.vaccineReminders(
            [record],
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertTrue(result.isEmpty,
            "과거 접종(scheduledDate < now - 7일)이면 모든 fireDate가 과거이므로 0건이어야 한다")
    }

    // MARK: - id 접두사 "vax-"

    func test_reminderIds_haveVaxPrefix() {
        let scheduledDate = d("2026-07-20")
        let now = d("2026-07-01")
        let record = makeRecord(vaccineId: "rotavirus", scheduledDate: scheduledDate)

        let result = NotificationScheduler.vaccineReminders(
            [record],
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertFalse(result.isEmpty)
        for req in result {
            XCTAssertTrue(req.id.hasPrefix("vax-"),
                "모든 알림 id는 'vax-' 접두사로 시작해야 한다. 실제: \(req.id)")
        }
    }

    /// id 형식: "vax-<vaccineId>-d7", "vax-<vaccineId>-d1", "vax-<vaccineId>-d0"
    func test_reminderIds_containVaccineIdAndSuffix() {
        let vaccineId = "ipv"
        let scheduledDate = d("2026-08-01")
        let now = d("2026-07-01")
        let record = makeRecord(vaccineId: vaccineId, scheduledDate: scheduledDate)

        let result = NotificationScheduler.vaccineReminders(
            [record],
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result.count, 3)
        let ids = Set(result.map(\.id))
        XCTAssertTrue(ids.contains("vax-\(vaccineId)-d7"))
        XCTAssertTrue(ids.contains("vax-\(vaccineId)-d1"))
        XCTAssertTrue(ids.contains("vax-\(vaccineId)-d0"))
    }

    // MARK: - fireDate 오름차순 (단일 record)

    func test_singleRecord_fireDatesAscending() {
        let scheduledDate = d("2026-09-01")
        let now = d("2026-08-01")
        let record = makeRecord(vaccineId: "mmr", scheduledDate: scheduledDate)

        let result = NotificationScheduler.vaccineReminders(
            [record],
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result.count, 3, "세 건 모두 생성되어야 한다")
        let dates = result.map(\.fireDate)
        XCTAssertLessThan(dates[0], dates[1], "D-7 fireDate < D-1 fireDate")
        XCTAssertLessThan(dates[1], dates[2], "D-1 fireDate < D-0 fireDate")
    }

    // MARK: - 복수 record: 결과가 오름차순으로 정렬되어야 한다
    // [주의 §2] 현재 구현은 sort를 하지 않으므로 코더가 sort를 추가해야 통과한다.

    func test_multipleVaccines_resultIsSortedByFireDate() {
        // record A: 더 먼 날짜, record B: 더 가까운 날짜
        let recordA = makeRecord(vaccineId: "hib",  scheduledDate: d("2026-10-01"))
        let recordB = makeRecord(vaccineId: "pcv",  scheduledDate: d("2026-08-01"))
        let now = d("2026-07-01")

        let result = NotificationScheduler.vaccineReminders(
            [recordA, recordB], // A를 먼저 전달해도 B의 fireDate가 더 빠름
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertFalse(result.isEmpty)
        let dates = result.map(\.fireDate)
        let sorted = dates.sorted()
        XCTAssertEqual(dates, sorted,
            "복수 record 결과는 fireDate 오름차순이어야 한다")
    }

    // MARK: - D-0 경계값: now == D-0 fireDate 정확히 같을 때 포함
    // [주의 §1] 현재 구현 `d0 >= now` 이므로 경계에서 포함.

    func test_futureVaccine_d0ExactlyNow_isIncluded() {
        let scheduledDate = d("2026-06-10")
        // D-0 fireDate = 2026-06-10 09:00:00 Asia/Seoul
        let d0FireDate = seoulCalendar.date(
            bySettingHour: 9, minute: 0, second: 0,
            of: scheduledDate
        )!
        let now = d0FireDate // now == D-0 fireDate

        let record = makeRecord(vaccineId: "varicella", scheduledDate: scheduledDate)
        let result = NotificationScheduler.vaccineReminders(
            [record],
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertTrue(result.contains(where: { $0.id == "vax-varicella-d0" }),
            "now == D-0 fireDate일 때 D-0 알림이 포함되어야 한다 (>= 경계)")
    }

    // MARK: - completedDate가 있어도 알림은 scheduledDate 기준으로 생성
    // [주의 §4] 코더가 completedDate로 완료 접종을 억제하면 이 테스트가 변경됨.

    func test_completedVaccine_stillGeneratesRemindersBasedOnScheduledDate() {
        let scheduledDate = d("2026-09-15")
        let now = d("2026-09-01")
        let record = makeRecord(
            vaccineId: "hepA",
            scheduledDate: scheduledDate,
            completedDate: d("2026-09-14") // 이미 완료됨
        )

        let result = NotificationScheduler.vaccineReminders(
            [record],
            now: now,
            calendar: seoulCalendar
        )

        // 현재 계약(구현)상 completedDate는 필터링에 영향 없음.
        // 코더가 완료 접종을 억제하면 isEmpty가 되어야 함.
        // 이 테스트는 현재 구현 계약을 문서화하는 용도.
        XCTAssertFalse(result.isEmpty,
            "[현재 계약] completedDate는 필터링 조건이 아니므로 scheduledDate 기준 알림이 생성된다. " +
            "코더가 완료 접종 억제를 추가하면 이 어설션을 isEmpty로 변경할 것.")
    }

    // MARK: - D-0 fireDate 고정 오전 9시 확인

    func test_d0_fireDateHour_is9AM() {
        let scheduledDate = d("2026-11-20")
        let now = d("2026-11-01")
        let record = makeRecord(vaccineId: "flu", scheduledDate: scheduledDate)

        let result = NotificationScheduler.vaccineReminders(
            [record],
            now: now,
            calendar: seoulCalendar
        )

        guard let d0 = result.first(where: { $0.id == "vax-flu-d0" }) else {
            return XCTFail("D-0 알림이 없다")
        }
        let hour = seoulCalendar.component(.hour, from: d0.fireDate)
        XCTAssertEqual(hour, 9, "D-0 알림은 오전 9시에 발송되어야 한다")
    }
}
