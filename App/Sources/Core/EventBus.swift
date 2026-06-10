import Combine
import Foundation

// MARK: - App Events

enum AppEvent {
    case milestoneAchieved(childId: UUID, milestone: String)
    case recordSaved(childId: UUID)
    case pregnancyEndedInLoss(pregnancyId: UUID)
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
