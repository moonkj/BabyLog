// CheckupReminderService.swift
// BabyLog · 산전 검진 권장 시기 로컬 알림(편의 기능). LMP 기준 권장 주차에서 예상일 계산.
// 민감영역: 닦달하지 않는 따뜻한 카피 + 의료 면책. 상실/멈춤 시 NotificationService가 prefix로 일괄 취소.

import Foundation
import UserNotifications

enum CheckupReminderService {
    /// 표준 산전 검진 권장 시기(시작 주차). 검진 일정 화면과 동일 순서.
    static let schedule: [(name: String, startWeek: Int, range: String)] = [
        ("초기 정밀 초음파·기형아 1차 검사", 11, "11~13주"),
        ("기형아 2차 검사",                 16, "16~20주"),
        ("정밀 초음파",                     20, "20~24주"),
        ("임신성 당뇨 검사",                24, "24~28주"),
        ("빈혈·소변 검사",                  28, "28주 전후"),
        ("GBS 검사",                        35, "35~37주"),
    ]

    /// 기준 LMP — lmpDate가 없으면 EDD-280일로 추정. 둘 다 없으면 nil.
    static func referenceLMP(lmpDate: Date?, eddDate: Date?) -> Date? {
        if let lmpDate { return lmpDate }
        if let eddDate { return Calendar.current.date(byAdding: .day, value: -280, to: eddDate) }
        return nil
    }

    /// 권장 시기 시작일(예상) — LMP + startWeek*7일.
    static func estimatedDate(lmp: Date?, startWeek: Int) -> Date? {
        guard let lmp else { return nil }
        return Calendar.current.date(byAdding: .day, value: startWeek * 7, to: lmp)
    }

    /// 다가오는 검진의 알림 요청들(권장 시기 3일 전 오전 10시, 미래만).
    static func reminders(pregnancyId: UUID, lmp: Date?) -> [LocalNotificationRequest] {
        guard let lmp else { return [] }
        let cal = Calendar.current
        let now = Date()
        var out: [LocalNotificationRequest] = []
        for (i, item) in schedule.enumerated() {
            guard let windowStart = estimatedDate(lmp: lmp, startWeek: item.startWeek),
                  let pre = cal.date(byAdding: .day, value: -3, to: windowStart) else { continue }
            let fire = cal.date(bySettingHour: 10, minute: 0, second: 0, of: pre) ?? pre
            guard fire > now else { continue }   // 지난 시기 알림은 만들지 않음(닦달 금지)
            out.append(LocalNotificationRequest(
                id: "preg-\(pregnancyId.uuidString)-checkup-\(i)",
                title: "곧 ‘\(item.name)’ 시기예요",
                body: "\(item.range) 권장 검사예요. 병원 예약을 미리 확인해 보세요. (의료 상담을 대체하지 않아요)",
                fireDate: fire))
        }
        return out
    }

    /// 알림 켜기 — 권한 요청 후 다가오는 검진 알림 예약. 권한 거부 시 false.
    @MainActor @discardableResult
    static func enable(pregnancyId: UUID, lmp: Date?) async -> Bool {
        let sched = UNPendingScheduler()
        guard await sched.requestAuthorization() else { return false }
        cancel(pregnancyId: pregnancyId)                  // 중복 방지 후 재예약
        sched.schedule(reminders(pregnancyId: pregnancyId, lmp: lmp))
        return true
    }

    /// 검진 알림만 취소(preg-<id>-checkup prefix).
    static func cancel(pregnancyId: UUID) {
        let center = UNUserNotificationCenter.current()
        let prefix = "preg-\(pregnancyId.uuidString)-checkup"
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
    }
}
