import Foundation

// MARK: - SampleData

/// 프리뷰 및 런치 시드용 샘플 데이터.
///
/// 디자인 시안 기준 — 아이 "지호" (남아, 생후 16개월)와 진행 중인 임신 1건을 포함한다.
/// SwiftUI #Preview 및 Xcode Simulator 초기 데이터로 활용한다.
enum SampleData {

    // MARK: - Fixed Reference Date

    /// 샘플 날짜 계산 기준: 2026-06-10
    private static let referenceDate: Date = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 10
        return cal.date(from: comps)!
    }()

    /// "yyyy-MM-dd" 문자열을 한국 표준시 자정으로 변환하는 내부 헬퍼
    private static func date(_ s: String) -> Date {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = TimeZone(identifier: "Asia/Seoul")!
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: s) else {
            fatalError("[SampleData] 날짜 파싱 실패: \(s)")
        }
        return d
    }

    // MARK: - Pregnancies

    /// 진행 중인 임신 1건 (태명 "별이", 산부인과: 행복여성병원)
    static let pregnancies: [Pregnancy] = [
        Pregnancy(
            id: UUID(uuidString: "A1B2C3D4-0001-0001-0001-000000000001")!,
            lmpDate:    date("2025-11-03"),
            eddDate:    date("2026-08-10"),
            fetusCount: 1,
            nickname:   "별이",
            clinic:     "행복여성병원",
            status:     .active
        )
    ]

    // MARK: - Children

    /// 아이 "지호" — 남아, 생후 약 16개월 (출생일 2025-02-10)
    static let children: [Child] = [
        Child(
            id: UUID(uuidString: "B2C3D4E5-0002-0002-0002-000000000002")!,
            name:          "지호",
            birthDate:     date("2025-02-10"),
            gender:        .boy,
            profileImageRef: nil,
            caregiverRole: "엄마",
            pregnancyId:   nil
        )
    ]

    // MARK: - GrowthRecords

    /// 지호의 성장 기록 (생후 6·12·16개월 측정)
    static let growth: [GrowthRecord] = [
        GrowthRecord(
            id: UUID(uuidString: "C3D4E5F6-0003-0003-0003-000000000003")!,
            childId:              UUID(uuidString: "B2C3D4E5-0002-0002-0002-000000000002")!,
            date:                 date("2025-08-10"),   // 생후 6개월
            heightCm:             67.0,
            weightKg:             7.8,
            headCircumferenceCm:  43.5
        ),
        GrowthRecord(
            id: UUID(uuidString: "D4E5F6A7-0004-0004-0004-000000000004")!,
            childId:              UUID(uuidString: "B2C3D4E5-0002-0002-0002-000000000002")!,
            date:                 date("2026-02-10"),   // 생후 12개월
            heightCm:             76.0,
            weightKg:             9.8,
            headCircumferenceCm:  46.0
        ),
        GrowthRecord(
            id: UUID(uuidString: "E5F6A7B8-0005-0005-0005-000000000005")!,
            childId:              UUID(uuidString: "B2C3D4E5-0002-0002-0002-000000000002")!,
            date:                 date("2026-06-10"),   // 생후 16개월 (기준일)
            heightCm:             81.5,
            weightKg:             11.0,
            headCircumferenceCm:  47.2
        )
    ]

    // MARK: - Factory

    /// 프리뷰·런치 시드용 `AppStore`를 반환한다.
    ///
    /// - Parameter bus: 주입할 이벤트 버스. nil이면 `.shared` 사용.
    /// - Returns: 샘플 pregnancies·children이 주입된 `AppStore` (영속화 없음).
    static func store(bus: EventBus = .shared) -> AppStore {
        AppStore(
            pregnancies: pregnancies,
            children:    children,
            bus:         bus
        )
    }
}
