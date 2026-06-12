// PriorityEngine.swift
// BabyLog — Features/Home
//
// 홈 화면 "지금 가장 중요한 것" 단일 카드 선정 엔진.
// SPEC.md 기능 10 §9.2 우선순위 엔진 구현.
// Foundation 전용 — UIKit/SwiftUI 의존 없음.

import Foundation

// MARK: - PriorityKind

enum PriorityKind: Equatable {
    case emergency
    case vaccine
    case subsidy
    case recordNudge
    case memory
}

// MARK: - PriorityItem

struct PriorityItem: Equatable {
    let kind: PriorityKind
    let title: String
    let subtitle: String
    /// 남은 일수. 해당 없는 항목(subsidy·recordNudge·memory)은 nil.
    let dDay: Int?
    /// 카드 액션 연결용 참조 id (vaccine→vaccineId 등). 해당 없으면 nil.
    var referenceId: String? = nil
}

// MARK: - PriorityEngine

enum PriorityEngine {

    // MARK: Public API

    /// 홈 우선순위 엔진 — "지금 가장 중요한 것" 단일 카드를 결정합니다.
    ///
    /// 규칙(결정적 순서):
    /// 1. `vaccines` 중 `scheduledDate`가 `now`~`now+7일` 이내이고 미완료(`completedDate == nil`)인
    ///    항목이 있으면, 가장 가까운 것 → `.vaccine` (dDay = 남은 일수, 당일=0).
    /// 2. (1 없음) `subsidies`가 비어있지 않으면 첫 항목 → `.subsidy` (dDay = nil).
    /// 3. (2 없음) `hasRecentRecord`가 false이면 → `.recordNudge`.
    /// 4. (실제 1년 전 기록이 있을 때만) → `.memory` ("1년 전 오늘"). 없으면 거짓 추억 대신 격려.
    ///
    /// - Parameters:
    ///   - vaccines: 아이의 전체 예방접종 레코드 목록.
    ///   - subsidies: 해당 아이 연령에 적용 가능한 정부지원금 목록.
    ///   - hasRecentRecord: 최근 기록 존재 여부 (호출 측에서 판단 기준 정의).
    ///   - yearAgoMemoryId: 약 1년 전(±며칠) 실제 기록의 id. 있으면 그 기록으로 '추억' 카드를
    ///     띄운다. nil이면 "1년 전 오늘"을 거짓으로 내세우지 않고 중립 격려 카드로 대체.
    ///   - now: 현재 시각 (테스트 주입 가능).
    ///   - calendar: 날짜 계산에 사용할 Calendar (기본 `.current`).
    /// - Returns: 선정된 `PriorityItem`, 또는 nil (반환될 수 없으나 시그니처 유연성 보존).
    static func topPriority(
        vaccines: [VaccineRecord],
        subsidies: [SubsidyInfo],
        hasRecentRecord: Bool,
        yearAgoMemoryId: String? = nil,
        now: Date,
        calendar: Calendar = .current
    ) -> PriorityItem? {

        // ── 규칙 1: 임박 예방접종 (0~7일 이내, 미완료) ──────────────────────
        if let soonest = soonestPendingVaccine(
            vaccines: vaccines,
            now: now,
            calendar: calendar
        ) {
            let dDay = daysFromNow(to: soonest.scheduledDate!, now: now, calendar: calendar)
            let title = vaccineTitle(for: soonest, dDay: dDay)
            let subtitle = vaccineSubtitle(for: soonest, dDay: dDay)
            return PriorityItem(kind: .vaccine, title: title, subtitle: subtitle, dDay: dDay, referenceId: soonest.vaccineId)
        }

        // ── 규칙 2: 신청 가능한 정부지원금 ──────────────────────────────────
        if let first = subsidies.first {
            return PriorityItem(
                kind: .subsidy,
                title: "정부지원금을 놓치지 마세요",
                subtitle: "\(first.name) 신청 가능해요",
                dDay: nil
            )
        }

        // ── 규칙 3: 기록 권유 ─────────────────────────────────────────────────
        if !hasRecentRecord {
            return PriorityItem(
                kind: .recordNudge,
                title: "오늘의 순간을 남겨볼까요?",
                subtitle: "사진 한 장이면 기록 끝 — 2탭이면 돼요",
                dDay: nil
            )
        }

        // ── 규칙 4: 추억 — 실제 1년 전 기록이 있을 때만 ───────────────────────
        if let memId = yearAgoMemoryId {
            return PriorityItem(
                kind: .memory,
                title: "1년 전 오늘을 기억하세요?",
                subtitle: "그날의 순간을 다시 만나보세요",
                dDay: nil,
                referenceId: memId
            )
        }

        // ── 규칙 5: 그 외 — 거짓 '추억' 대신 따뜻한 격려(기록 유도) ─────────────
        return PriorityItem(
            kind: .recordNudge,
            title: "오늘도 기록을 이어가요",
            subtitle: "작은 순간도 쌓이면 1년 뒤 소중한 추억이 돼요",
            dDay: nil
        )
    }

    // MARK: Private Helpers

    /// `now`부터 `now+7일` 이내이고 미완료(`completedDate == nil`)인 접종 중
    /// scheduledDate가 가장 가까운 VaccineRecord를 반환합니다.
    private static func soonestPendingVaccine(
        vaccines: [VaccineRecord],
        now: Date,
        calendar: Calendar
    ) -> VaccineRecord? {
        let todayStart = calendar.startOfDay(for: now)
        guard let windowEnd = calendar.date(byAdding: .day, value: 7, to: todayStart) else {
            return nil
        }
        // windowEnd는 7일 후 자정(startOfDay 기준) — 당일(0) 포함, 7일 후(7) 포함
        let windowEndInclusive = calendar.date(byAdding: .day, value: 1, to: windowEnd) ?? windowEnd

        return vaccines
            .filter { record in
                guard record.completedDate == nil,
                      let scheduled = record.scheduledDate else { return false }
                let scheduledStart = calendar.startOfDay(for: scheduled)
                return scheduledStart >= todayStart && scheduledStart < windowEndInclusive
            }
            .min { lhs, rhs in
                let l = calendar.startOfDay(for: lhs.scheduledDate!)
                let r = calendar.startOfDay(for: rhs.scheduledDate!)
                return l < r
            }
    }

    /// 기준일(now)부터 target까지의 일수(달력 startOfDay 기준).
    /// 당일 = 0, 내일 = 1.
    private static func daysFromNow(to target: Date, now: Date, calendar: Calendar) -> Int {
        let todayStart  = calendar.startOfDay(for: now)
        let targetStart = calendar.startOfDay(for: target)
        return calendar.dateComponents([.day], from: todayStart, to: targetStart).day ?? 0
    }

    /// 접종 카드 제목 (한국어, 안심 톤 — 또래 비교·등수 없음)
    private static func vaccineTitle(for record: VaccineRecord, dDay: Int) -> String {
        switch dDay {
        case 0:
            return "오늘 예방접종 날이에요"
        case 1:
            return "내일 예방접종이 있어요"
        default:
            return "예방접종이 \(dDay)일 남았어요"
        }
    }

    /// 접종 카드 부제목
    private static func vaccineSubtitle(for record: VaccineRecord, dDay: Int) -> String {
        let vaccineId = record.vaccineId
        if let hospital = record.hospital, !hospital.isEmpty {
            return "\(vaccineId) · \(hospital)"
        }
        return "\(vaccineId) · 소아과 방문을 권장해요"
    }
}
