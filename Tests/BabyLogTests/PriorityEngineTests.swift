// PriorityEngineTests.swift
// BabyLogTests
//
// QA — PriorityEngine.topPriority(vaccines:subsidies:hasRecentRecord:now:calendar:) 계약 검증
//
// ===== 코더와 어긋날 수 있는 지점 =====
//
// [1] PriorityEngine / PriorityItem / PriorityKind 타입이 아직 존재하지 않는다.
//     코더가 아래 계약대로 구현해야 컴파일된다.
//     최소 계약:
//       enum PriorityKind { case emergency, vaccine, subsidy, recordNudge, memory }
//       struct PriorityItem { let kind: PriorityKind; let referenceId: String? }
//       enum PriorityEngine {
//           static func topPriority(
//               vaccines: [VaccineRecord],
//               subsidies: [SubsidyInfo],
//               hasRecentRecord: Bool,
//               now: Date,
//               calendar: Calendar
//           ) -> PriorityItem?
//       }
//
// [2] "7일 내 접종"의 경계: 오늘 포함 7일(now ... now+7일)인지, now < scheduledDate <= now+7일인지
//     테스트는 now+0일(당일), +7일(경계) 모두 .vaccine을 기대한다.
//     코더가 strictly < 7일로 구현하면 test_vaccine_exactly7DaysAway_returnsVaccine 실패.
//
// [3] "가장 가까운" 접종 기준이 다수일 때: 동점(同日) 처리 방식은 계약에 없음.
//     테스트는 단일 최솟값만 검증한다.
//
// [4] hasRecentRecord=true이고 접종·지원금 없을 때 .memory를 반환한다는 계약.
//     "전부 충족" 해석이 애매할 수 있음. 테스트는 이를 명시적으로 검증한다.
//
// [5] 빈 입력(vaccines:[], subsidies:[], hasRecentRecord:false) → .recordNudge 기대.
//     hasRecentRecord=true → .memory 기대. nil을 반환하면 테스트 실패.
//
// [6] PriorityItem이 Equatable하지 않을 수 있으므로 kind만 비교한다.

import XCTest
@testable import BabyLog

// MARK: - 계약 타입 (코더 구현 대상)
// 아래 타입들은 코더가 App/Sources 어딘가에 추가해야 한다.
// 테스트는 @testable import BabyLog을 통해 접근한다.

final class PriorityEngineTests: XCTestCase {

    // MARK: - Helpers

    private var seoulCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }()

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

    private func makeVaccine(
        vaccineId: String = "bcg",
        scheduledDate: Date,
        completedDate: Date? = nil
    ) -> VaccineRecord {
        VaccineRecord(
            id: UUID(),
            childId: UUID(),
            vaccineId: vaccineId,
            scheduledDate: scheduledDate,
            completedDate: completedDate,
            hospital: nil
        )
    }

    private func makeSubsidy(id: String = "sub-001") -> SubsidyInfo {
        SubsidyInfo(
            id: id,
            name: "아동수당",
            amountKRW: 100_000,
            eligibility: "만 8세 미만",
            applyURL: nil
        )
    }

    // MARK: - 7일 내 접종 있으면 .vaccine

    func test_vaccineWithin7Days_returnsVaccineKind() {
        let now = d("2026-06-10")
        // scheduledDate = now + 3일
        let scheduled = seoulCalendar.date(byAdding: .day, value: 3, to: now)!
        let vaccine = makeVaccine(vaccineId: "dtap", scheduledDate: scheduled)

        let result = PriorityEngine.topPriority(
            vaccines: [vaccine],
            subsidies: [],
            hasRecentRecord: true,
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result?.kind, .vaccine,
            "7일 내 접종이 있으면 .vaccine을 반환해야 한다")
    }

    /// 당일 접종도 .vaccine [주의 §2]
    func test_vaccineToday_returnsVaccineKind() {
        let now = d("2026-06-10")
        let vaccine = makeVaccine(vaccineId: "hepb", scheduledDate: now)

        let result = PriorityEngine.topPriority(
            vaccines: [vaccine],
            subsidies: [],
            hasRecentRecord: false,
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result?.kind, .vaccine, "당일 접종도 .vaccine을 반환해야 한다")
    }

    /// 정확히 7일 후 접종 [주의 §2]
    func test_vaccineExactly7DaysAway_returnsVaccineKind() {
        let now = d("2026-06-10")
        let scheduled = seoulCalendar.date(byAdding: .day, value: 7, to: now)!
        let vaccine = makeVaccine(vaccineId: "mmr", scheduledDate: scheduled)

        let result = PriorityEngine.topPriority(
            vaccines: [vaccine],
            subsidies: [],
            hasRecentRecord: false,
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result?.kind, .vaccine,
            "정확히 7일 후 접종도 .vaccine 범위에 포함되어야 한다 (경계값 포함 계약)")
    }

    /// 8일 후 접종 → .vaccine 아님
    func test_vaccine8DaysAway_doesNotReturnVaccineKind() {
        let now = d("2026-06-10")
        let scheduled = seoulCalendar.date(byAdding: .day, value: 8, to: now)!
        let vaccine = makeVaccine(vaccineId: "mmr", scheduledDate: scheduled)

        let result = PriorityEngine.topPriority(
            vaccines: [vaccine],
            subsidies: [],
            hasRecentRecord: false,
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertNotEqual(result?.kind, .vaccine,
            "8일 후 접종은 7일 이내 범위 밖이므로 .vaccine이 아니어야 한다")
    }

    /// 복수 접종 중 가장 가까운 것 반환
    func test_multipleVaccines_returnsClosest() {
        let now = d("2026-06-10")
        let close = seoulCalendar.date(byAdding: .day, value: 2, to: now)!
        let far   = seoulCalendar.date(byAdding: .day, value: 5, to: now)!

        let vaccineClose = makeVaccine(vaccineId: "close-vax", scheduledDate: close)
        let vaccineFar   = makeVaccine(vaccineId: "far-vax",   scheduledDate: far)

        let result = PriorityEngine.topPriority(
            vaccines: [vaccineFar, vaccineClose], // 멀리 있는 것 먼저 전달
            subsidies: [],
            hasRecentRecord: false,
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result?.kind, .vaccine)
        XCTAssertEqual(result?.referenceId, "close-vax",
            "복수 접종 중 가장 가까운 vaccineId를 referenceId로 반환해야 한다")
    }

    // MARK: - 접종 없고 지원금 있으면 .subsidy

    func test_noVaccine_withSubsidy_returnsSubsidyKind() {
        let now = d("2026-06-10")
        let subsidy = makeSubsidy()

        let result = PriorityEngine.topPriority(
            vaccines: [],
            subsidies: [subsidy],
            hasRecentRecord: true,
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result?.kind, .subsidy,
            "7일 내 접종 없고 지원금이 있으면 .subsidy를 반환해야 한다")
    }

    /// 먼 접종(8일 후) + 지원금 → .subsidy
    func test_vaccineOutsideWindow_withSubsidy_returnsSubsidy() {
        let now = d("2026-06-10")
        let farVaccine = makeVaccine(
            vaccineId: "flu",
            scheduledDate: seoulCalendar.date(byAdding: .day, value: 30, to: now)!
        )
        let subsidy = makeSubsidy()

        let result = PriorityEngine.topPriority(
            vaccines: [farVaccine],
            subsidies: [subsidy],
            hasRecentRecord: false,
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result?.kind, .subsidy,
            "7일 범위 밖 접종은 .vaccine 조건을 만족하지 않으므로 지원금이 있으면 .subsidy")
    }

    // MARK: - 접종·지원금 없고 hasRecentRecord=false → .recordNudge

    func test_noVaccine_noSubsidy_noRecentRecord_returnsRecordNudge() {
        let now = d("2026-06-10")

        let result = PriorityEngine.topPriority(
            vaccines: [],
            subsidies: [],
            hasRecentRecord: false,
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result?.kind, .recordNudge,
            "접종·지원금 없고 최근 기록 없으면 .recordNudge를 반환해야 한다")
    }

    // MARK: - 전부 충족(최근 기록 있음) → .memory [주의 §4]

    func test_noVaccine_noSubsidy_hasRecentRecord_returnsMemory() {
        let now = d("2026-06-10")

        let result = PriorityEngine.topPriority(
            vaccines: [],
            subsidies: [],
            hasRecentRecord: true,
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result?.kind, .memory,
            "접종·지원금 없고 최근 기록이 있으면 .memory를 반환해야 한다")
    }

    // MARK: - 우선순위: vaccine > subsidy

    func test_vaccineWithinWindow_andSubsidy_returnsVaccine() {
        let now = d("2026-06-10")
        let vaccine = makeVaccine(
            vaccineId: "pcv",
            scheduledDate: seoulCalendar.date(byAdding: .day, value: 1, to: now)!
        )
        let subsidy = makeSubsidy()

        let result = PriorityEngine.topPriority(
            vaccines: [vaccine],
            subsidies: [subsidy],
            hasRecentRecord: true,
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertEqual(result?.kind, .vaccine,
            "7일 내 접종이 있으면 지원금보다 우선하여 .vaccine을 반환해야 한다")
    }

    // MARK: - nil 반환 없음 보장 (모든 경우 non-nil) [주의 §5]

    func test_topPriority_neverReturnsNilForValidInput() {
        let now = d("2026-06-10")

        // 가장 빈 케이스
        let result = PriorityEngine.topPriority(
            vaccines: [],
            subsidies: [],
            hasRecentRecord: false,
            now: now,
            calendar: seoulCalendar
        )

        XCTAssertNotNil(result,
            "모든 조건 미충족(빈 입력)에서도 topPriority는 nil이 아닌 값을 반환해야 한다")
    }
}
