import Foundation

// MARK: - LocalNotificationRequest

/// 로컬 알림 요청 값 타입. 순수 데이터 컨테이너로 UI/테스트 양쪽에서 사용.
struct LocalNotificationRequest: Equatable, Identifiable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

// MARK: - NotificationScheduler

/// 알림 요청을 순수하게 빌드하는 정적 빌더.
/// 부수효과 없음 — UNUserNotificationCenter 직접 참조 금지.
/// 등록·권한 요청은 NotificationCenterClient(UNPendingScheduler)에서 담당한다.
enum NotificationScheduler {

    // MARK: - Vaccine Reminders

    /// 예방접종 D-7 / D-1 / 당일(D-0) 알림 요청 목록을 반환한다.
    ///
    /// - Parameters:
    ///   - vaccines: 알림 대상 예방접종 기록 배열.
    ///   - now: 기준 시각. 이 시각보다 이른 fireDate는 결과에서 제외.
    ///   - calendar: 날짜 계산에 사용할 Calendar (기본 `.current`).
    /// - Returns: fireDate >= now 인 LocalNotificationRequest 배열.
    ///   id 형식 — "vax-<vaccineId>-d7" / "vax-<vaccineId>-d1" / "vax-<vaccineId>-d0"
    static func vaccineReminders(
        _ vaccines: [VaccineRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> [LocalNotificationRequest] {
        var requests: [LocalNotificationRequest] = []

        for vaccine in vaccines {
            // scheduledDate가 nil이면 스킵
            guard let scheduledDate = vaccine.scheduledDate else { continue }

            let vaccineId = vaccine.vaccineId

            // D-7: 접종 예정일 7일 전 오전 9시
            if let d7 = fireDate(base: scheduledDate, offsetDays: -7, hour: 9, calendar: calendar),
               d7 >= now {
                requests.append(LocalNotificationRequest(
                    id: "vax-\(vaccineId)-d7",
                    title: "예방접종 D-7",
                    body: "일주일 뒤 예방접종이 있어요. 미리 병원을 예약해 두면 여유롭게 다녀올 수 있답니다 💉",
                    fireDate: d7
                ))
            }

            // D-1: 접종 예정일 1일 전 오전 9시
            if let d1 = fireDate(base: scheduledDate, offsetDays: -1, hour: 9, calendar: calendar),
               d1 >= now {
                requests.append(LocalNotificationRequest(
                    id: "vax-\(vaccineId)-d1",
                    title: "예방접종 D-1",
                    body: "내일 예방접종 날이에요! 아이 컨디션을 미리 살펴보고, 수첩과 보험 카드를 챙겨두세요 🌟",
                    fireDate: d1
                ))
            }

            // D-0: 접종 당일 오전 9시
            if let d0 = fireDate(base: scheduledDate, offsetDays: 0, hour: 9, calendar: calendar),
               d0 >= now {
                requests.append(LocalNotificationRequest(
                    id: "vax-\(vaccineId)-d0",
                    title: "오늘 예방접종 날이에요",
                    body: "오늘 예방접종이 있는 날이에요. 건강하게 잘 다녀오길 응원해요! 접종 후 30분은 병원 근처에서 지켜봐 주세요 🤍",
                    fireDate: d0
                ))
            }
        }

        // 복수 접종 시에도 전역 fireDate 오름차순 (QA 교차레이어 발견 반영)
        return requests.sorted { $0.fireDate < $1.fireDate }
    }

    // MARK: - Generic Reminder Builder

    /// 범용 단일 알림 요청 빌더.
    /// - Parameters:
    ///   - id: 알림 고유 식별자.
    ///   - title: 알림 제목.
    ///   - body: 알림 본문.
    ///   - fireDate: 알림을 발송할 시각.
    /// - Returns: 대응하는 LocalNotificationRequest.
    static func reminder(
        id: String,
        title: String,
        body: String,
        fireDate: Date
    ) -> LocalNotificationRequest {
        LocalNotificationRequest(id: id, title: title, body: body, fireDate: fireDate)
    }

    // MARK: - Private Helpers

    /// base 날짜에서 offsetDays만큼 이동한 뒤 지정 hour(분·초 0)로 고정한 Date를 반환.
    /// 계산 실패 시 nil.
    private static func fireDate(
        base: Date,
        offsetDays: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date? {
        guard let shifted = calendar.date(byAdding: .day, value: offsetDays, to: base) else {
            return nil
        }
        var components = calendar.dateComponents([.year, .month, .day], from: shifted)
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }
}
