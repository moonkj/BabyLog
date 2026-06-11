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

    // MARK: - Memory Reminders (1년 전 오늘)

    /// "N년 전 오늘" 추억 사진 알림. 사진이 있는 다이어리의 기념일(1·2·3주년 중 가장 가까운 미래)에
    /// 오전 10시 알림을 만든다. 너무 잦지 않도록 한 달에 최대 1건, 향후 13개월 이내만.
    ///
    /// - Returns: fireDate 오름차순 LocalNotificationRequest 배열 (id: "memory-<entryId>")
    static func memoryReminders(
        diaryEntries: [DiaryEntry],
        childName: String,
        now: Date,
        calendar: Calendar = .current,
        maxCount: Int = 12
    ) -> [LocalNotificationRequest] {
        guard let horizon = calendar.date(byAdding: .month, value: 13, to: now) else { return [] }
        // 사진 있는 기록만, 오래된 순(주년이 먼저 오는 순)으로
        let photoEntries = diaryEntries
            .filter { !$0.photoRefList.isEmpty }
            .sorted { $0.date < $1.date }

        var usedMonths: Set<String> = []
        var results: [LocalNotificationRequest] = []
        let mk = DateFormatter(); mk.dateFormat = "yyyy-MM"

        for entry in photoEntries {
            guard let anniv = nextAnniversary(of: entry.date, after: now, calendar: calendar),
                  anniv <= horizon,
                  let fire = fireDate(base: anniv, offsetDays: 0, hour: 10, calendar: calendar),
                  fire >= now else { continue }
            let monthKey = mk.string(from: fire)
            if usedMonths.contains(monthKey) { continue }   // 한 달 1건
            usedMonths.insert(monthKey)

            let years = max(1, calendar.component(.year, from: fire) - calendar.component(.year, from: entry.date))
            let body: String
            if let c = entry.content, !c.isEmpty {
                body = "\(childName)의 '\(c)' — 그날의 사진을 다시 볼까요? 🤍"
            } else {
                body = "\(childName)의 그날 사진을 다시 볼까요? 🤍"
            }
            results.append(LocalNotificationRequest(
                id: "memory-\(entry.id.uuidString)",
                title: "📸 \(years)년 전 오늘",
                body: body,
                fireDate: fire
            ))
        }
        return Array(results.sorted { $0.fireDate < $1.fireDate }.prefix(maxCount))
    }

    /// 기록 날짜의 월·일을, now 이후로 가장 가까운 미래의 같은 월·일(주년)로 반환.
    private static func nextAnniversary(of date: Date, after now: Date, calendar: Calendar) -> Date? {
        let md = calendar.dateComponents([.month, .day], from: date)
        var year = calendar.component(.year, from: now)
        for _ in 0...2 {
            var comp = DateComponents(); comp.year = year; comp.month = md.month; comp.day = md.day
            if let candidate = calendar.date(from: comp),
               candidate > date,                     // 기록일 이후의 주년
               calendar.startOfDay(for: candidate) >= calendar.startOfDay(for: now) {
                return candidate
            }
            year += 1
        }
        return nil
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
