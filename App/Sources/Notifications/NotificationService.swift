import Foundation
import Combine
import UserNotifications

// MARK: - NotificationScheduling Protocol

/// 알림 스케줄링 추상화. 테스트 시 mock으로 교체 가능.
protocol NotificationScheduling: AnyObject {
    func cancelPregnancyNotifications(pregnancyId: UUID)
}

// MARK: - UNNotificationScheduler (Concrete)

/// UserNotifications 기반 구체 구현체.
/// 알림 식별자 prefix "preg-<pregnancyId>" 로 등록된 알림을 일괄 제거한다.
final class UNNotificationScheduler: NotificationScheduling {

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// 해당 임신 ID prefix를 가진 보류 중인 알림을 모두 취소한다.
    /// prefix 규칙: "preg-<pregnancyId.uuidString>"
    func cancelPregnancyNotifications(pregnancyId: UUID) {
        let prefix = "preg-\(pregnancyId.uuidString)"

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let matchingIds = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            guard !matchingIds.isEmpty else { return }
            self.center.removePendingNotificationRequests(withIdentifiers: matchingIds)
        }
    }
}

// MARK: - NotificationService

/// EventBus를 구독해 상실 이벤트 발생 시 해당 임신 관련 알림을 자동 차단한다.
/// 사용자가 별도 설정하지 않아도 상실 직후 즉시 모든 임신 알림이 멈춘다.
final class NotificationService {

    private let scheduler: NotificationScheduling
    private let bus: EventBus
    private var cancellables = Set<AnyCancellable>()

    init(scheduler: NotificationScheduling, bus: EventBus = .shared) {
        self.scheduler = scheduler
        self.bus = bus
    }

    /// EventBus 구독을 시작한다.
    /// `.pregnancyEndedInLoss(pregnancyId:)` 이벤트 수신 시
    /// 해당 임신 ID에 연결된 모든 알림을 즉시 취소한다.
    func start() {
        bus.events
            .sink { [weak self] event in
                guard let self else { return }
                if case .pregnancyEndedInLoss(let pregnancyId) = event {
                    self.scheduler.cancelPregnancyNotifications(pregnancyId: pregnancyId)
                }
            }
            .store(in: &cancellables)
    }
}
