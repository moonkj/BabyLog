import Combine
import Foundation

// MARK: - App Events

enum AppEvent {
    case milestoneAchieved(childId: UUID, milestone: String)
    case recordSaved(childId: UUID)
    case pregnancyEndedInLoss(pregnancyId: UUID)
    /// 기록 멈춤(일시중단) — 상실은 아니지만 모든 주차 알림·태아 가이드·권유 알림을 즉시 중단.
    case pregnancyPaused(pregnancyId: UUID)
}

// MARK: - Event Bus

final class EventBus {

    static let shared = EventBus()

    let subject = PassthroughSubject<AppEvent, Never>()

    init() {}

    func publish(_ e: AppEvent) {
        subject.send(e)
    }

    var events: AnyPublisher<AppEvent, Never> {
        subject.eraseToAnyPublisher()
    }
}
