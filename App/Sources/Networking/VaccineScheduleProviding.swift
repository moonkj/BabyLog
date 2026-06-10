// VaccineScheduleProviding.swift
// BabyLog — Networking
//
// 출처: 질병관리청 예방접종도우미 API (예방접종 스케줄)
// ⚠️ 이 정보는 의료 상담을 대체하지 않습니다.
//    실제 접종 일정은 반드시 담당 의료진과 확인하세요.
//
// NOTE: 실제 API 키는 B4(키 관리 담당)가 관리합니다.
//       현재 구현은 Mock 데이터만 반환합니다.

import Foundation

// MARK: - Protocol

/// 질병관리청 표준 예방접종 일정을 제공합니다.
/// ⚠️ 반환된 일정은 의료 상담을 대체하지 않으며, 접종 전 반드시 소아과 전문의와 확인하세요.
protocol VaccineScheduleProviding {
    /// 출생일 기준 표준 예방접종 일정을 반환합니다.
    /// - Parameter birthDate: 아이의 실제 출생일
    /// - Returns: 권장 접종일이 설정된 `VaccineRecord` 배열 (childId = .zero — 호출부에서 교체 필요)
    func schedule(birthDate: Date) async throws -> [VaccineRecord]
}

// MARK: - Mock Implementation

/// 질병관리청 예방접종 스케줄 Mock (BCG·B형간염·DTaP 등 8건)
/// ⚠️ 의료 상담을 대체하지 않습니다. 실제 접종 일정은 담당 의료진과 확인하세요.
final class MockVaccineScheduleProvider: VaccineScheduleProviding {

    init() {}

    func schedule(birthDate: Date) async throws -> [VaccineRecord] {
        // 결정적 샘플 데이터 — 질병관리청 표준 일정 참조
        // childId 는 .zero 로 두며, 호출부(ViewModel/Service)에서 실제 childId로 교체합니다.
        let entries: [(vaccineId: String, offsetMonths: Int)] = [
            ("BCG",       0),   // 결핵 — 생후 0개월 (4주 이내)
            ("HepB-1",    0),   // B형간염 1차 — 출생 직후
            ("HepB-2",    1),   // B형간염 2차 — 생후 1개월
            ("DTaP-1",    2),   // DTaP(디프테리아·파상풍·백일해) 1차 — 생후 2개월
            ("IPV-1",     2),   // 폴리오 1차 — 생후 2개월
            ("Hib-1",     2),   // b형 헤모필루스 인플루엔자 1차 — 생후 2개월
            ("PCV-1",     2),   // 폐렴구균 1차 — 생후 2개월
            ("DTaP-2",    4),   // DTaP 2차 — 생후 4개월
        ]

        return entries.map { entry in
            VaccineRecord(
                id: UUID(),
                childId: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                vaccineId: entry.vaccineId,
                scheduledDate: Calendar.current.date(
                    byAdding: .month,
                    value: entry.offsetMonths,
                    to: birthDate
                ),
                completedDate: nil,
                hospital: nil
            )
        }
    }
}
