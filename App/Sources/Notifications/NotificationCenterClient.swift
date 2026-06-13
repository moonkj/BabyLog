import Foundation
import UserNotifications

// MARK: - PendingScheduler Protocol

/// 알림 권한 요청과 LocalNotificationRequest 등록을 담당하는 프로토콜.
/// 앱 런치 시 팀장이 UNPendingScheduler(또는 Mock)를 주입해 연결한다.
protocol PendingScheduler {
    /// UNUserNotificationCenter 권한을 요청한다.
    /// - Returns: 사용자가 허용하면 true, 거부하거나 오류 시 false.
    func requestAuthorization() async -> Bool

    /// LocalNotificationRequest 배열을 UNUserNotificationCenter에 등록한다.
    /// 이미 동일 id가 등록된 경우 덮어쓴다.
    func schedule(_ reqs: [LocalNotificationRequest])
}

// MARK: - UNPendingScheduler (Concrete)

/// UNUserNotificationCenter 기반 구체 구현체.
/// - 권한 요청: alert + sound + badge
/// - 트리거: UNCalendarNotificationTrigger (fireDate → DateComponents)
/// - 중복 id: addNotificationRequest는 같은 identifier를 덮어씀(UNUserNotificationCenter 기본 동작)
final class UNPendingScheduler: PendingScheduler {

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    // MARK: requestAuthorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    // MARK: schedule

    func schedule(_ reqs: [LocalNotificationRequest]) {
        for req in reqs {
            let content = UNMutableNotificationContent()
            content.title = req.title
            content.body = req.body
            content.sound = .default

            // fireDate → DateComponents (년·월·일·시·분·초)
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: req.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: req.id,
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                // 등록 실패는 무시 — 알림은 편의 기능이므로 앱 흐름을 막지 않는다.
                // 필요 시 팀장이 로깅 레이어를 주입할 수 있다.
                _ = error
            }
        }
    }

    // MARK: cancel

    /// "memory-" prefix로 등록된 추억 알림을 모두 취소한다(설정에서 추억 알림 OFF 시).
    func cancelMemoryReminders() {
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix("memory-") }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
